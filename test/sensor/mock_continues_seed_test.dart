import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:aelos/data/seed/seed_loader.dart';
import 'package:aelos/domain/models/sensor_record.dart';
import 'package:aelos/domain/verification/chain_verifier.dart';
import 'package:aelos/sensor/mock/mock_chain_state.dart';
import 'package:aelos/sensor/mock/mock_sensor_connection.dart';
import 'package:aelos/sensor/sensor_connection.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// The demo depends on this: the mock sensor picks up the seeded violin's
/// chain where it ends, so live records extend 30 days of signed history.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock continues the seeded violin chain', () async {
    final seed = await SeedLoader().load();
    final violin = seed.instruments
        .firstWhere((i) => i.instrument.id == 'violin-mittenwald');
    final seeded = violin.records;
    final state = MockChainState.fromRecords(seeded);

    final produced = <SensorRecord>[];
    fakeAsync((async) {
      final mock = MockSensorConnection(
        chainState: state,
        readingInterval: MockSensorConnection.demoReadingInterval,
        random: Random(3),
        now: async.getClock(seed.endTime.add(const Duration(minutes: 5))).now,
      );
      mock.records.listen(produced.add);
      unawaited(mock.connect('1AFB'));
      async.elapse(const Duration(seconds: 1));
      unawaited(mock.sync(seeded.last.seq + 1));
      async.elapse(const Duration(minutes: 3));
      unawaited(mock.sendDemoCommand(const DemoCommand(DemoAction.impact)));
      async.elapse(const Duration(minutes: 2));
      unawaited(mock.dispose());
      async.flushMicrotasks();
    });

    expect(produced.first.seq, seeded.last.seq + 1);
    expect(produced.map((r) => r.kind), contains(RecordKind.impact));
    final result = await verifyChain(
      [for (final r in produced) r.json],
      publicKey: base64Decode(violin.instrument.sensorPublicKey),
      prevOfFirst: state.lastHash,
    );
    expect(result.isValid, isTrue, reason: '${result.reason} at ${result.failedAtSeq}');
  });
}
