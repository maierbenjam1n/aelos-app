import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aelos/domain/models/device_info.dart';
import 'package:aelos/domain/models/live_reading.dart';
import 'package:aelos/domain/models/sensor_record.dart';
import 'package:aelos/domain/verification/chain_verifier.dart';
import 'package:aelos/sensor/mock/mock_chain_state.dart';
import 'package:aelos/sensor/mock/mock_sensor_connection.dart';
import 'package:aelos/sensor/mock/test_key.dart';
import 'package:aelos/sensor/sensor_connection.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

final _testKey = jsonDecode(
  File('test/vectors/test_key.json').readAsStringSync(),
) as Map<String, Object?>;
final _publicKey = base64Decode(_testKey['public_key']! as String);
final _start = DateTime.utc(2026, 10, 24, 12);

/// A mock on the fake clock, with listeners collecting everything it sends.
final class _Harness {
  _Harness(this.async, {MockChainState? chainState, int seed = 7})
    : mock = MockSensorConnection(
        chainState: chainState,
        readingInterval: MockSensorConnection.demoReadingInterval,
        random: Random(seed),
        now: async.getClock(_start).now,
      ) {
    mock.status.listen(statuses.add);
    mock.records.listen(records.add);
    mock.live.listen(live.add);
  }

  final FakeAsync async;
  final MockSensorConnection mock;
  final statuses = <ConnectionStatus>[];
  final records = <SensorRecord>[];
  final live = <LiveReading>[];

  List<int> get seqs => [for (final r in records) r.seq];

  DeviceInfo connect() {
    DeviceInfo? info;
    unawaited(mock.connect('1AFB').then((i) => info = i));
    async.elapse(const Duration(seconds: 1));
    return info!;
  }

  void connectAndSync(int from) {
    connect();
    unawaited(mock.sendTime(async.getClock(_start).now()));
    unawaited(mock.sync(from));
    async.elapse(const Duration(seconds: 1));
  }

  void demo(DemoCommand cmd) {
    unawaited(mock.sendDemoCommand(cmd));
    async.flushMicrotasks();
  }

  void minutes(int n) => async.elapse(Duration(minutes: n));

  /// Disposes the mock and checks that it left nothing running.
  void dispose() {
    unawaited(mock.dispose());
    async.flushMicrotasks();
    expect(async.pendingTimers, isEmpty);
  }
}

Future<ChainResult> _verify(
  List<SensorRecord> records, {
  List<int>? prevOfFirst,
}) => verifyChain(
  [for (final r in records) r.json],
  publicKey: _publicKey,
  prevOfFirst: prevOfFirst,
);

List<SensorRecord> _vectorRecords() {
  final v = jsonDecode(
    File('test/vectors/chain_valid.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return [
    for (final r in v['records']! as List<Object?>)
      SensorRecord.parse(jsonEncode(r)),
  ];
}

void main() {
  test('test key matches test/vectors/test_key.json', () {
    final hex = [
      for (final b in testKeySeed) b.toRadixString(16).padLeft(2, '0'),
    ].join();
    expect(hex, _testKey['seed_hex']);
  });

  test('connection sequence; nothing on records before sync', () {
    fakeAsync((async) {
      final h = _Harness(async);
      List<DiscoveredSensor>? found;
      h.mock.scan().listen((s) => found = s);

      async.elapse(const Duration(milliseconds: 1100));
      expect(found, isNull);
      async.elapse(const Duration(milliseconds: 200));
      expect(found!.single.name, 'Aelos-1AFB');

      DeviceInfo? info;
      unawaited(h.mock.connect(found!.single.id).then((i) => info = i));
      async.elapse(const Duration(milliseconds: 500));
      expect(info, isNull);
      async.elapse(const Duration(milliseconds: 200));
      expect(info!.id, '1AFB');
      expect(info!.firmware, '0.1.0');
      expect(info!.publicKey, _testKey['public_key']);

      unawaited(h.mock.sendTime(async.getClock(_start).now()));
      h.minutes(5);
      expect(h.records, isEmpty, reason: 'no records before sync');
      expect(h.live, hasLength(150), reason: 'live every 2 s');

      unawaited(h.mock.sync(1));
      async.elapse(const Duration(seconds: 1));
      expect(h.seqs, [1, 2, 3, 4, 5, 6]);
      expect(h.records.first.kind, RecordKind.boot);
      expect(
        h.records.skip(1).map((r) => r.kind),
        everyElement(RecordKind.reading),
      );
      expect(h.statuses, [
        ConnectionStatus.disconnected,
        ConnectionStatus.scanning,
        ConnectionStatus.connecting,
        ConnectionStatus.connected,
        ConnectionStatus.syncing,
        ConnectionStatus.connected,
      ]);
      h.dispose();
    });
  });

  test('every record verifies across disconnects and demo commands', () async {
    late List<SensorRecord> received;
    late List<SensorRecord> stored;
    fakeAsync((async) {
      final h = _Harness(async)..connectAndSync(1);
      h
        ..minutes(10)
        ..demo(const DemoCommand(DemoAction.impact))
        ..demo(const DemoCommand(DemoAction.freefall, freeFallMs: 450))
        ..demo(const DemoCommand(DemoAction.dry))
        ..minutes(3);

      h.mock.simulateDisconnect();
      expect(h.mock.currentStatus, ConnectionStatus.disconnected);
      final heldBefore = h.records.length;
      final liveBefore = h.live.length;
      h
        ..minutes(5)
        ..demo(const DemoCommand(DemoAction.impact, tenthsG: 150))
        ..minutes(2);
      expect(h.records, hasLength(heldBefore), reason: 'link is down');
      expect(h.live, hasLength(liveBefore));

      h.mock.simulateReconnect();
      async.elapse(const Duration(seconds: 1));
      expect(h.mock.currentStatus, ConnectionStatus.connected);
      expect(h.records, hasLength(heldBefore), reason: 'nothing before sync');

      unawaited(h.mock.sync(h.records.last.seq + 1));
      async.elapse(const Duration(seconds: 1));
      h
        ..demo(const DemoCommand(DemoAction.normal))
        ..minutes(5);

      // A second, app-initiated disconnect and connect.
      unawaited(h.mock.disconnect());
      h
        ..minutes(3)
        ..connectAndSync(h.records.last.seq + 1)
        ..minutes(2);
      async.elapse(const Duration(seconds: 1));

      received = h.records;
      stored = h.mock.chainState.records;
      h.dispose();
    });

    expect(received.map((r) => r.seq), [
      for (var s = 1; s <= stored.length; s++) s,
    ]);
    expect(received.map((r) => r.raw), stored.map((r) => r.raw));
    expect(received.where((r) => r.kind == RecordKind.impact), hasLength(2));
    expect(received.where((r) => r.kind == RecordKind.freeFall), hasLength(1));

    final result = await _verify(received);
    expect(
      result.isValid,
      isTrue,
      reason: '${result.reason} at ${result.failedAtSeq}',
    );

    final verifier = ChainVerifier(publicKey: _publicKey);
    for (final r in received) {
      expect(await verifier.add(r.json), isNull);
    }
  });

  test(
    'sync(from) replays exactly s >= from in order, then continues live',
    () {
      fakeAsync((async) {
        final h = _Harness(async)
          ..connectAndSync(1)
          ..minutes(12);
        final all = [...h.records];
        expect(all, hasLength(13));

        unawaited(h.mock.disconnect());
        h.records.clear();
        h.statuses.clear();
        h.connectAndSync(4);
        expect(h.seqs, [for (var s = 4; s <= 13; s++) s]);
        expect(h.records.map((r) => r.raw), all.skip(3).map((r) => r.raw));
        expect(h.statuses, contains(ConnectionStatus.syncing));
        expect(h.mock.currentStatus, ConnectionStatus.connected);

        h.demo(const DemoCommand(DemoAction.impact));
        expect(h.seqs.last, 14);
        h.minutes(1);
        expect(h.seqs.last, 15);

        // A new sync on the same connection restarts the replay.
        h.records.clear();
        unawaited(h.mock.sync(14));
        async.elapse(const Duration(seconds: 1));
        expect(h.seqs, [14, 15]);
        h.dispose();
      });
    },
  );

  test('replay is paced so syncing is visible but short', () {
    fakeAsync((async) {
      final h = _Harness(async)..connect();
      h.minutes(30);
      unawaited(h.mock.sync(1));
      async.elapse(const Duration(milliseconds: 100));
      expect(h.records.length, inInclusiveRange(4, 6));
      expect(h.mock.currentStatus, ConnectionStatus.syncing);
      async.elapse(const Duration(seconds: 1));
      expect(h.records, hasLength(31));
      expect(h.mock.currentStatus, ConnectionStatus.connected);
      h.dispose();
    });
  });

  test('impact and freefall produce i and f records with the right values', () {
    fakeAsync((async) {
      final h = _Harness(async)..connectAndSync(1);
      h
        ..demo(const DemoCommand(DemoAction.impact))
        ..demo(const DemoCommand(DemoAction.impact, tenthsG: 123))
        ..demo(const DemoCommand(DemoAction.freefall))
        ..demo(const DemoCommand(DemoAction.freefall, freeFallMs: 500));
      async.elapse(const Duration(milliseconds: 100));

      final events = h.records.skip(1).toList();
      expect(events.map((r) => r.kind), [
        RecordKind.impact,
        RecordKind.impact,
        RecordKind.freeFall,
        RecordKind.freeFall,
      ]);
      expect(events.map((r) => r.tenthsG), [72, 123, null, null]);
      expect(events.map((r) => r.freeFallMs), [null, null, 310, 500]);
      expect(events.first.json.keys.toSet(), {'s', 'ts', 'k', 'g', 'sig'});
      expect(
        events.first.time,
        async.getClock(_start).now().copyWith(millisecond: 0, microsecond: 0),
      );
      h.dispose();
    });
  });

  test('dry lowers humidity about 1.5 %/min down to 30 %, normal recovers', () {
    fakeAsync((async) {
      final h = _Harness(async)..connectAndSync(1);
      h.minutes(1);
      final before = h.live.last.tenthsHumidity;

      h
        ..demo(const DemoCommand(DemoAction.dry))
        ..minutes(4);
      final afterFour = h.live.last.tenthsHumidity;
      expect(before - afterFour, inInclusiveRange(50, 70));
      expect(h.records.last.kind, RecordKind.reading);
      expect(h.records.last.tenthsHumidity, lessThan(before - 40));

      h.minutes(20);
      expect(h.live.last.tenthsHumidity, inInclusiveRange(300, 302));

      h
        ..demo(const DemoCommand(DemoAction.normal))
        ..minutes(10);
      expect(h.live.last.tenthsHumidity, inInclusiveRange(450, 520));
      h.dispose();
    });
  });

  test('climate stays in range over a day and is deterministic', () {
    List<SensorRecord> run(int seed) => fakeAsync((async) {
      final mock = MockSensorConnection(
        random: Random(seed),
        now: async.getClock(_start).now,
      );
      async.elapse(const Duration(hours: 24));
      final records = mock.chainState.records;
      unawaited(mock.dispose());
      async.flushMicrotasks();
      return records;
    });

    final a = run(3);
    final readings = a.where((r) => r.kind == RecordKind.reading).toList();
    expect(readings, hasLength(144));
    final temps = readings.map((r) => r.tenthsCelsius!).toList();
    final hums = readings.map((r) => r.tenthsHumidity!).toList();
    expect(temps, everyElement(inInclusiveRange(180, 230)));
    expect(hums, everyElement(inInclusiveRange(450, 520)));
    expect(temps.reduce(max) - temps.reduce(min), greaterThan(40));
    expect(hums.reduce(max) - hums.reduce(min), greaterThan(20));

    expect(run(3).map((r) => r.raw), a.map((r) => r.raw));
    expect(run(4).map((r) => r.raw), isNot(a.map((r) => r.raw)));
  });

  test('sendTime adopts the app clock only when off by more than 120 s', () {
    fakeAsync((async) {
      final h = _Harness(async)..connect();
      final now = async.getClock(_start).now();
      unawaited(h.mock.sendTime(now.add(const Duration(seconds: 100))));
      unawaited(h.mock.sync(1));
      h.demo(const DemoCommand(DemoAction.impact));
      async.elapse(const Duration(seconds: 1));
      expect(h.records.last.time.difference(now).inSeconds, lessThan(5));

      unawaited(h.mock.sendTime(now.add(const Duration(hours: 1))));
      h.demo(const DemoCommand(DemoAction.impact));
      async.elapse(const Duration(seconds: 1));
      expect(h.records.last.time.difference(now).inSeconds, closeTo(3600, 5));
      h.dispose();
    });
  });

  test('connect waits while out of range; disconnect cancels the wait', () {
    fakeAsync((async) {
      final h = _Harness(async)..connect();
      h.mock.simulateDisconnect();

      DeviceInfo? info;
      unawaited(h.mock.connect('Aelos-1AFB').then((i) => info = i));
      h.minutes(1);
      expect(info, isNull);
      expect(h.mock.currentStatus, ConnectionStatus.disconnected);
      h.mock.simulateReconnect();
      async.elapse(const Duration(seconds: 1));
      expect(info, isNotNull);
      expect(h.mock.currentStatus, ConnectionStatus.connected);

      h.mock.simulateDisconnect();
      Object? error;
      unawaited(
        h.mock
            .connect('1AFB')
            .then<void>((_) {}, onError: (Object e) => error = e),
      );
      async.flushMicrotasks();
      unawaited(h.mock.disconnect());
      async.flushMicrotasks();
      expect(error, isA<StateError>());

      expect(() => h.mock.connect('BEEF'), throwsArgumentError);
      expect(() => h.mock.sync(1), throwsStateError);
      h.dispose();
    });
  });

  group('continues an injected chain', () {
    test('from stored records (chain_valid vectors)', () async {
      final vectors = _vectorRecords();
      final state = MockChainState.fromRecords(vectors);
      late List<SensorRecord> received;
      fakeAsync((async) {
        final h = _Harness(async, chainState: state)
          ..connectAndSync(1)
          ..minutes(3)
          ..demo(const DemoCommand(DemoAction.impact));
        async.elapse(const Duration(seconds: 1));
        received = h.records;
        h.dispose();
      });

      expect(received.take(8).map((r) => r.raw), vectors.map((r) => r.raw));
      final fresh = received.skip(8).toList();
      expect(fresh.first.seq, 9);
      expect(fresh.first.kind, RecordKind.boot);
      expect(fresh, hasLength(5));

      final continuation = await _verify(fresh, prevOfFirst: state.lastHash);
      expect(continuation.isValid, isTrue);
      final whole = await _verify(received);
      expect(whole.isValid, isTrue);
    });

    test('from last seq and hash only', () async {
      final vectors = _vectorRecords();
      final state = MockChainState(
        lastSeq: 8,
        lastHash: recordHash(vectors.last.json),
      );
      late List<SensorRecord> received;
      fakeAsync((async) {
        final h = _Harness(async, chainState: state)
          ..connectAndSync(1)
          ..minutes(2);
        received = h.records;
        h.dispose();
      });

      expect(received.map((r) => r.seq), [9, 10, 11]);
      expect(
        (await _verify(received, prevOfFirst: state.lastHash)).isValid,
        isTrue,
      );
      expect((await _verify([...vectors, ...received])).isValid, isTrue);
    });

    test('from another mock, e.g. after a transport switch', () async {
      late List<SensorRecord> first;
      late List<SensorRecord> second;
      fakeAsync((async) {
        final a = _Harness(async)
          ..connectAndSync(1)
          ..minutes(3);
        first = a.records;
        final state = a.mock.chainState;
        a.dispose();

        final b = _Harness(async, chainState: state, seed: 9)
          ..connectAndSync(state.lastSeq + 1)
          ..minutes(2);
        second = b.records;
        b.dispose();
      });

      expect(second.first.seq, first.last.seq + 1);
      expect((await _verify([...first, ...second])).isValid, isTrue);
    });

    test('rejects an inconsistent state', () {
      final vectors = _vectorRecords();
      expect(
        () => MockChainState(
          lastSeq: 8,
          lastHash: List.filled(32, 1),
          records: vectors,
        ),
        throwsArgumentError,
      );
      expect(
        () => MockChainState.fromRecords([
          ...vectors.take(3),
          ...vectors.skip(4),
        ]),
        throwsArgumentError,
      );
    });
  });
}
