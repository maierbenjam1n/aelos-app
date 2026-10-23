import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../domain/models/live_reading.dart';
import '../domain/models/sensor_record.dart';
import '../domain/thresholds/alert.dart';
import '../domain/thresholds/replay_summary.dart';
import '../domain/verification/chain_verifier.dart';
import '../sensor/mock/mock_chain_state.dart';
import '../sensor/mock/mock_sensor_connection.dart';
import '../sensor/mock/test_key.dart';
import '../sensor/sensor_connection.dart';
import 'instruments_notifier.dart';

final transportProvider = NotifierProvider<TransportNotifier, SensorTransport>(
  TransportNotifier.new,
);

class TransportNotifier extends Notifier<SensorTransport> {
  @override
  SensorTransport build() => AppConfig.initialTransport;

  void set(SensorTransport transport) => state = transport;
}

/// The active transport. The mock continues the seeded violin's chain, on the
/// seed's timeline, so its records extend the history seamlessly.
final sensorConnectionProvider = FutureProvider<SensorConnection>((ref) async {
  final transport = ref.watch(transportProvider);
  final seed = await ref.watch(seedProvider.future);
  final offset = ref.watch(appStartProvider).difference(seed.endTime);
  switch (transport) {
    case SensorTransport.mock:
      final violin = seed.instruments.firstWhere(
        (s) => s.instrument.sensorId == testDeviceId,
      );
      final mock = MockSensorConnection(
        chainState: MockChainState.fromRecords(violin.records),
        readingInterval: MockSensorConnection.demoReadingInterval,
        now: () => DateTime.now().toUtc().subtract(offset),
      );
      ref.onDispose(mock.dispose);
      return mock;
    case SensorTransport.ws:
    case SensorTransport.ble:
      throw UnimplementedError('${transport.name} transport arrives in build step 4');
  }
});

/// What happened while the sensor was out of reach, for the reconnect card.
final class AwaySummary {
  const AwaySummary({
    required this.instrumentId,
    required this.start,
    required this.end,
    required this.recordCount,
    required this.minTenthsHumidity,
    required this.maxTenthsHumidity,
    this.alerts,
  });

  final String instrumentId;

  /// Signed times of the first and last replayed record.
  final DateTime start;
  final DateTime end;
  final int recordCount;
  final int? minTenthsHumidity;
  final int? maxTenthsHumidity;

  /// Null when nothing crossed a threshold: "all calm while you were away".
  final ReplaySummary? alerts;
}

final class SessionState {
  const SessionState({
    required this.instrumentId,
    required this.status,
    this.live,
    this.lastSync,
    this.error,
  });

  final String instrumentId;
  final ConnectionStatus status;
  final LiveReading? live;

  /// Local time the last record arrived.
  final DateTime? lastSync;
  final String? error;

  SessionState copyWith({
    ConnectionStatus? status,
    LiveReading? live,
    DateTime? lastSync,
    String? error,
  }) =>
      SessionState(
        instrumentId: instrumentId,
        status: status ?? this.status,
        live: live ?? this.live,
        lastSync: lastSync ?? this.lastSync,
        error: error ?? this.error,
      );
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState?>(
  SessionNotifier.new,
);

/// Alerts raised by live (not replayed) records, for the takeover and
/// notifications.
final alertEventsProvider = StreamProvider<Alert>(
  (ref) => ref.watch(sessionProvider.notifier).alertEvents,
);

final awaySummaryProvider = NotifierProvider<AwaySummaryNotifier, AwaySummary?>(
  AwaySummaryNotifier.new,
);

class AwaySummaryNotifier extends Notifier<AwaySummary?> {
  @override
  AwaySummary? build() => null;

  void show(AwaySummary summary) => state = summary;
  void dismiss() => state = null;
}

/// Connects one instrument's sensor and keeps its history current: runs the
/// protocol's connection sequence (again after every reconnect), verifies
/// each record before storing it, and evaluates thresholds.
class SessionNotifier extends Notifier<SessionState?> {
  final _alerts = StreamController<Alert>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  SensorConnection? _connection;
  ChainVerifier? _verifier;
  Future<void> _queue = Future.value();
  final _replay = <SensorRecord>[];
  bool _syncing = false;
  bool _wasDisconnected = false;

  Stream<Alert> get alertEvents => _alerts.stream;

  /// The mock, when it is the active transport, for the demo panel.
  MockSensorConnection? get mock => switch (_connection) {
        final MockSensorConnection m => m,
        _ => null,
      };

  @override
  SessionState? build() {
    ref.onDispose(() {
      _stop();
      unawaited(_alerts.close());
    });
    return null;
  }

  /// Starts the session for [instrumentId]. Pass [alreadyConnected] when the
  /// pairing screen has just connected the same transport.
  Future<void> start(String instrumentId, {bool alreadyConnected = false}) async {
    _stop();
    final connection = await ref.read(sensorConnectionProvider.future);
    final data = ref.read(instrumentProvider(instrumentId));
    if (data == null) throw StateError('Unknown instrument $instrumentId');
    final last = data.records.lastOrNull;
    _connection = connection;
    _verifier = ChainVerifier(
      publicKey: base64Decode(data.instrument.sensorPublicKey),
      prevOfFirst: last == null ? null : recordHash(last.json),
      lastSeq: last?.seq,
    );
    state = SessionState(instrumentId: instrumentId, status: ConnectionStatus.connecting);

    _subscriptions
      ..add(connection.status.listen(_onStatus))
      ..add(connection.records.listen((r) => _queue = _queue.then((_) => _onRecord(r))))
      ..add(connection.live.listen((l) => state = state?.copyWith(live: l)));

    if (!alreadyConnected) {
      final info = await connection.connect(data.instrument.sensorId);
      if (info.publicKey != data.instrument.sensorPublicKey) {
        state = state?.copyWith(
          error: 'This sensor signs with a different key than the one paired with '
              '${data.instrument.name}.',
        );
        await connection.disconnect();
        return;
      }
    }
    await _handshake();
  }

  Future<void> _handshake() async {
    final connection = _connection!;
    final data = ref.read(instrumentProvider(state!.instrumentId))!;
    await connection.sendTime(data.sensorNow);
    await connection.sync((_verifier!.lastSeq ?? 0) + 1);
  }

  void _onStatus(ConnectionStatus status) {
    final previous = state?.status;
    state = state?.copyWith(status: status);
    switch (status) {
      case ConnectionStatus.syncing:
        _syncing = true;
      case ConnectionStatus.connected when previous == ConnectionStatus.syncing:
        _queue = _queue.then((_) => _flushReplay());
      case ConnectionStatus.connected when _wasDisconnected:
        // The sensor came back on its own; rerun the connection sequence.
        _wasDisconnected = false;
        unawaited(_handshake());
      // Only a drop from a live link counts; a new listener may first be told
      // the transport's idle state.
      case ConnectionStatus.disconnected
          when previous == ConnectionStatus.connected || previous == ConnectionStatus.syncing:
        _wasDisconnected = true;
      default:
    }
  }

  Future<void> _onRecord(SensorRecord record) async {
    // A repeated sync can replay records we already hold.
    if (record.seq <= (_verifier!.lastSeq ?? 0)) return;
    final failure = await _verifier!.add(record.json);
    if (failure != null) {
      // Never store what doesn't verify; the history must stay provable.
      debugPrint('Dropped record ${record.seq}: ${failure.name}');
      return;
    }
    state = state?.copyWith(lastSync: DateTime.now());
    if (_syncing) {
      _replay.add(record);
      return;
    }
    final notifier = ref.read(instrumentsProvider.notifier);
    for (final alert in notifier.append(state!.instrumentId, [record])) {
      _alerts.add(alert);
    }
  }

  Future<void> _flushReplay() async {
    _syncing = false;
    if (_replay.isEmpty) return;
    final records = [..._replay];
    _replay.clear();
    final alerts = ref.read(instrumentsProvider.notifier).append(state!.instrumentId, records);
    final humidity = [
      for (final r in records)
        if (r.tenthsHumidity != null) r.tenthsHumidity!,
    ];
    // A replay of just the boot record after a fresh start isn't news.
    if (records.length < 2 && alerts.isEmpty) return;
    ref.read(awaySummaryProvider.notifier).show(
          AwaySummary(
            instrumentId: state!.instrumentId,
            start: records.first.time,
            end: records.last.time,
            recordCount: records.length,
            minTenthsHumidity: humidity.isEmpty ? null : humidity.reduce((a, b) => a < b ? a : b),
            maxTenthsHumidity: humidity.isEmpty ? null : humidity.reduce((a, b) => a > b ? a : b),
            alerts: summarizeReplay(alerts),
          ),
        );
  }

  void _stop() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    _replay.clear();
    _syncing = false;
    _wasDisconnected = false;
    _connection = null;
  }
}
