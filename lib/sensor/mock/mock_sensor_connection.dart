import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../../domain/models/device_info.dart';
import '../../domain/models/live_reading.dart';
import '../../domain/models/sensor_record.dart';
import '../../domain/verification/canonical_json.dart';
import '../sensor_connection.dart';
import 'mock_chain_state.dart';
import 'mock_environment.dart';
import 'test_key.dart';

/// An in-process sensor that behaves like the Pi per docs/ble-protocol.md:
/// signed, hash-chained records, `sync` replay, `live` every 2 s and the demo
/// commands. It is the on-stage fallback, so it needs no hardware or network.
///
/// The sensor runs from construction until [dispose], connected or not: it
/// keeps writing records while the app is away, and `sync` delivers them.
final class MockSensorConnection implements SensorConnection {
  /// Powers on a sensor that signs with [privateSeed] (default: the TEST key)
  /// and continues [chainState] (default: a fresh chain). Pass [now] and
  /// [random] to make it deterministic in tests.
  MockSensorConnection({
    List<int>? privateSeed,
    MockChainState? chainState,
    this.readingInterval = defaultReadingInterval,
    Random? random,
    DateTime Function()? now,
    bool writeBootRecord = true,
    this.firmware = '0.1.0',
    this.scanDelay = const Duration(milliseconds: 1200),
    this.connectDelay = const Duration(milliseconds: 600),
    this.replayInterval = const Duration(milliseconds: 20),
  }) : _now = now ?? DateTime.now,
       _environment = MockEnvironment(random ?? Random(1)) {
    final state = chainState ?? MockChainState.fresh();
    _lastSeq = state.lastSeq;
    _lastHash = state.lastHash;
    _firstStoredSeq = state.firstStoredSeq;
    _store.addAll([for (final r in state.records) r.raw]);
    _ready = _init(privateSeed ?? testKeySeed);
    _chain = _ready;
    if (writeBootRecord) unawaited(_write({'k': 'b'}));
    _readingTimer = Timer.periodic(readingInterval, (_) => _writeReading());
  }

  /// Reading interval of the real sensor (docs/ble-protocol.md 6).
  static const defaultReadingInterval = Duration(seconds: 600);

  /// Shorter reading interval for rehearsals and the stage demo.
  static const demoReadingInterval = Duration(seconds: 60);

  /// How often `live` sends while connected (docs/ble-protocol.md 4.2).
  static const liveInterval = Duration(seconds: 2);

  /// A scan stops by itself after this long, like a BLE scan timeout.
  static const scanTimeout = Duration(seconds: 15);

  /// Time between two signed `r` records.
  final Duration readingInterval;

  /// Firmware version reported in `info`.
  final String firmware;

  /// Delay before [scan] reports the sensor, so the pairing animation plays.
  final Duration scanDelay;

  /// Delay between `connecting` and `connected`.
  final Duration connectDelay;

  /// Pause between replayed records: 50 per second, as the spec recommends.
  final Duration replayInterval;

  static final _ed25519 = DartEd25519(sha512: const DartSha512());

  final DateTime Function() _now;
  final MockEnvironment _environment;

  late final Future<void> _ready;
  late final SimpleKeyPair _keyPair;
  late final DeviceInfo _info;

  // Chain: every record is signed in order through [_chain], because each
  // signature needs the hash of the record before it.
  late Future<void> _chain;
  late int _lastSeq;
  late Uint8List _lastHash;
  late final int _firstStoredSeq;
  final _store = <String>[];

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _liveController = StreamController<LiveReading>.broadcast();
  final _recordsController = StreamController<SensorRecord>.broadcast();
  final _scans = <StreamController<List<DiscoveredSensor>>>{};

  var _status = ConnectionStatus.disconnected;
  var _clockOffset = Duration.zero;
  var _inRange = true;
  var _wantConnection = false;
  var _connected = false;
  var _disposed = false;
  Future<void>? _connecting;
  Completer<void>? _wakeUp;

  // Next sequence number to deliver on `records`; null until `sync` on the
  // current connection.
  int? _cursor;

  late final Timer _readingTimer;
  Timer? _liveTimer;
  Timer? _pumpTimer;

  /// The `info` payload, once the key has been loaded.
  Future<DeviceInfo> get info => _ready.then((_) => _info);

  /// The latest status; [status] also starts with it for every new listener.
  ConnectionStatus get currentStatus => _status;

  /// Whether the `dry` scenario is running.
  bool get isDrying => _environment.isDrying;

  /// Everything the sensor has stored so far, to continue it in a new mock
  /// (e.g. after switching transports). Records still being signed are not
  /// included; await [settled] first to get them.
  MockChainState get chainState => MockChainState(
    lastSeq: _lastSeq,
    lastHash: _lastHash,
    records: [for (final raw in _store) SensorRecord.parse(raw)],
  );

  /// Completes once every record triggered so far is signed and stored.
  Future<void> get settled => _chain;

  @override
  Stream<ConnectionStatus> get status => Stream.multi((listener) {
    listener.add(_status);
    final sub = _statusController.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.onCancel = sub.cancel;
  });

  @override
  Stream<LiveReading> get live => _liveController.stream;

  @override
  Stream<SensorRecord> get records => _recordsController.stream;

  @override
  Stream<List<DiscoveredSensor>> scan() {
    _checkNotDisposed();
    Timer? found;
    Timer? timeout;
    late final StreamController<List<DiscoveredSensor>> controller;
    void stop() {
      found?.cancel();
      timeout?.cancel();
      _scans.remove(controller);
      if (_status == ConnectionStatus.scanning) {
        _setStatus(ConnectionStatus.disconnected);
      }
    }

    controller = StreamController(
      onListen: () {
        _scans.add(controller);
        if (!_connected && _connecting == null) {
          _setStatus(ConnectionStatus.scanning);
        }
        found = Timer(scanDelay, () async {
          await _ready;
          if (!_inRange || controller.isClosed) return;
          controller.add([
            DiscoveredSensor(
              id: _info.id,
              name: 'Aelos-${_info.id}',
              rssi: -58,
            ),
          ]);
        });
        timeout = Timer(scanTimeout, () {
          stop();
          unawaited(controller.close());
        });
      },
      onCancel: stop,
    );
    return controller.stream;
  }

  /// Accepts the device ID (`1AFB`) or the advertised name (`Aelos-1AFB`).
  /// While the sensor is out of range ([simulateDisconnect]) this waits, like
  /// a BLE auto-connect, and completes once it is back.
  @override
  Future<DeviceInfo> connect(String sensorId) async {
    _checkNotDisposed();
    await _ready;
    if (sensorId != _info.id && sensorId != 'Aelos-${_info.id}') {
      throw ArgumentError.value(sensorId, 'sensorId', 'No such sensor');
    }
    _wantConnection = true;
    if (!_connected) await (_connecting ??= _establishLink());
    return _info;
  }

  @override
  Future<void> sendTime(DateTime utcNow) async {
    _checkConnected();
    final diff = utcNow.difference(_sensorNow());
    if (diff.inSeconds.abs() > 120) _clockOffset += diff;
  }

  @override
  Future<void> sync(int fromSeq) async {
    _checkConnected();
    _pumpTimer?.cancel();
    _pumpTimer = null;
    final cursor = max(fromSeq, _firstStoredSeq);
    _cursor = cursor;
    if (cursor - _firstStoredSeq < _store.length) {
      _setStatus(ConnectionStatus.syncing);
    }
    _pump();
  }

  /// Unlike a real BLE write this also works while disconnected, so the demo
  /// can stage an event that happens while the phone is out of range.
  /// Completes once an `impact` or `freefall` record is signed and stored.
  @override
  Future<void> sendDemoCommand(DemoCommand cmd) async {
    _checkNotDisposed();
    switch (cmd.action) {
      case DemoAction.impact:
        await _write({'k': 'i', 'g': cmd.tenthsG ?? 72});
      case DemoAction.freefall:
        await _write({'k': 'f', 'ms': cmd.freeFallMs ?? 310});
      case DemoAction.dry:
        _environment.startDrying(_now());
      case DemoAction.normal:
        _environment.endSimulations(_now());
    }
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _wantConnection = false;
    _stopScans();
    _linkDown();
    _setStatus(ConnectionStatus.disconnected);
    _wake();
  }

  /// Demo control: the sensor goes out of range. The link drops, `records`
  /// and `live` go quiet, but the sensor keeps writing records.
  void simulateDisconnect() {
    if (_disposed) return;
    _inRange = false;
    _linkDown();
    _setStatus(ConnectionStatus.disconnected);
  }

  /// Demo control: the sensor is back in range. If the app still wants the
  /// connection, the link comes back by itself (`connecting`, `connected`);
  /// the app then sends `time` and `sync` again, as on any new connection.
  void simulateReconnect() {
    if (_disposed || _inRange) return;
    _inRange = true;
    _wake();
    if (_wantConnection && !_connected && _connecting == null) {
      final attempt = _connecting = _establishLink();
      unawaited(attempt.catchError((Object _) {}));
    }
  }

  /// Stops the sensor: cancels every timer and closes every stream.
  Future<void> dispose() async {
    if (_disposed) return;
    _setStatus(ConnectionStatus.disconnected);
    _disposed = true;
    _wantConnection = false;
    _readingTimer.cancel();
    _linkDown();
    _stopScans();
    _wake();
    await Future.wait([
      _statusController.close(),
      _liveController.close(),
      _recordsController.close(),
    ]);
  }

  Future<void> _init(List<int> seed) async {
    _keyPair = await _ed25519.newKeyPairFromSeed(seed);
    final pk = (await _keyPair.extractPublicKey()).bytes;
    final idBytes = const DartSha256().hashSync(pk).bytes.take(2);
    _info = DeviceInfo(
      id: [for (final b in idBytes) b.toRadixString(16).padLeft(2, '0')]
          .join()
          .toUpperCase(),
      firmware: firmware,
      publicKey: base64Encode(pk),
    );
  }

  Future<void> _establishLink() async {
    try {
      while (true) {
        while (!_inRange) {
          _setStatus(ConnectionStatus.disconnected);
          await (_wakeUp ??= Completer<void>()).future;
          _checkStillWanted();
        }
        _setStatus(ConnectionStatus.connecting);
        _stopScans();
        await Future<void>.delayed(connectDelay);
        _checkStillWanted();
        if (_inRange) break;
      }
      _connected = true;
      _setStatus(ConnectionStatus.connected);
      _liveTimer = Timer.periodic(liveInterval, (_) => _sendLive());
    } finally {
      _connecting = null;
    }
  }

  void _checkStillWanted() {
    if (_disposed || !_wantConnection) {
      throw StateError('Connection attempt cancelled');
    }
  }

  void _linkDown() {
    _connected = false;
    _cursor = null;
    _pumpTimer?.cancel();
    _pumpTimer = null;
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  void _wake() {
    _wakeUp?.complete();
    _wakeUp = null;
  }

  void _stopScans() {
    for (final scan in [..._scans]) {
      unawaited(scan.close());
    }
    _scans.clear();
  }

  /// Delivers stored records from [_cursor] on, one per [replayInterval].
  /// Once caught up, a new record goes out as soon as it is stored.
  void _pump() {
    final cursor = _cursor;
    if (_disposed || !_connected || cursor == null || _pumpTimer != null) {
      return;
    }
    final index = cursor - _firstStoredSeq;
    if (index >= _store.length) {
      if (_status == ConnectionStatus.syncing) {
        _setStatus(ConnectionStatus.connected);
      }
      return;
    }
    _cursor = cursor + 1;
    _recordsController.add(SensorRecord.parse(_store[index]));
    _pumpTimer = Timer(replayInterval, () {
      _pumpTimer = null;
      _pump();
    });
  }

  void _writeReading() {
    final sample = _environment.sample(_now());
    unawaited(
      _write({'k': 'r', 't': sample.tenthsCelsius, 'h': sample.tenthsHumidity}),
    );
  }

  void _sendLive() {
    if (_disposed || !_connected) return;
    final sample = _environment.sample(_now());
    _liveController.add(
      LiveReading.fromJson({
        't': sample.tenthsCelsius,
        'h': sample.tenthsHumidity,
        'ts': _sensorTimestamp(),
      }),
    );
  }

  /// Stamps [body] with the event time now, then signs and stores it as the
  /// next record once every earlier record is done.
  Future<void> _write(Map<String, Object> body) {
    final record = {...body, 'ts': _sensorTimestamp()};
    final done = _chain.then((_) => _signAndStore(record));
    _chain = done.catchError(
      (Object e, StackTrace s) => Zone.current.handleUncaughtError(e, s),
    );
    return done;
  }

  Future<void> _signAndStore(Map<String, Object> body) async {
    if (_disposed) return;
    final seq = _lastSeq + 1;
    final record = <String, Object?>{...body, 's': seq};
    // docs/ble-protocol.md 5.3: sign prev ‖ canonical, then hash the full form.
    final canonical = canonicalBytes(record);
    final message = Uint8List(32 + canonical.length)
      ..setAll(0, _lastHash)
      ..setAll(32, canonical);
    final signature = await _ed25519.sign(message, keyPair: _keyPair);
    if (_disposed) return;
    record['sig'] = base64Encode(signature.bytes);
    final full = canonicalBytes(record, includeSig: true);
    _lastHash = Uint8List.fromList(const DartSha256().hashSync(full).bytes);
    _lastSeq = seq;
    _store.add(utf8.decode(full));
    _pump();
  }

  DateTime _sensorNow() => _now().add(_clockOffset);

  int _sensorTimestamp() => _sensorNow().millisecondsSinceEpoch ~/ 1000;

  void _setStatus(ConnectionStatus status) {
    if (_disposed || _status == status) return;
    _status = status;
    _statusController.add(status);
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('MockSensorConnection is disposed');
  }

  void _checkConnected() {
    _checkNotDisposed();
    if (!_connected) throw StateError('Not connected');
  }
}
