import 'dart:async';

import 'package:aelos/data/instruments_notifier.dart';
import 'package:aelos/data/sensor_session.dart';
import 'package:aelos/domain/models/sensor_record.dart';
import 'package:aelos/domain/thresholds/alert.dart';
import 'package:aelos/domain/thresholds/threshold_config.dart';
import 'package:aelos/sensor/sensor_connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _violin = 'violin-mittenwald';

Future<void> _until(bool Function() done, {Duration timeout = const Duration(seconds: 10)}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// End to end on the mock with real timers: the demo's data path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('live session verifies, stores, alerts and summarises a reconnect', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final seeded = await container.read(instrumentsProvider.future);
    final before = seeded.firstWhere((i) => i.id == _violin).records.length;
    expect(seeded, hasLength(3));

    final alerts = <Alert>[];
    container.listen(alertEventsProvider, (_, next) {
      if (next.value case final a?) alerts.add(a);
    });
    final session = container.read(sessionProvider.notifier);
    await session.start(_violin);
    await _until(() => container.read(sessionProvider)?.status == ConnectionStatus.connected);
    await _until(() => container.read(instrumentProvider(_violin))!.records.length > before);

    // The first sync replays the mock's boot record: stored, but no card.
    expect(container.read(instrumentProvider(_violin))!.records.last.kind, RecordKind.boot);
    expect(container.read(awaySummaryProvider), isNull);

    await session.mock!.sendDemoCommand(const DemoCommand(DemoAction.impact));
    await _until(() => alerts.isNotEmpty);
    expect(alerts.single.rule, ThresholdRule.impact);
    expect(container.read(instrumentProvider(_violin))!.records.last.kind, RecordKind.impact);

    session.mock!.simulateDisconnect();
    await _until(() => container.read(sessionProvider)!.status == ConnectionStatus.disconnected);
    await session.mock!.sendDemoCommand(const DemoCommand(DemoAction.freefall));
    await session.mock!.sendDemoCommand(const DemoCommand(DemoAction.impact));
    session.mock!.simulateReconnect();

    await _until(() => container.read(awaySummaryProvider) != null);
    final away = container.read(awaySummaryProvider)!;
    expect(away.instrumentId, _violin);
    expect(away.recordCount, greaterThanOrEqualTo(2));
    expect(away.alerts!.headline, isNotEmpty);
    // Replayed alerts go to the summary, not the takeover.
    expect(alerts, hasLength(1));
    // Every stored record extends the verified chain without gaps.
    final records = container.read(instrumentProvider(_violin))!.records;
    for (var i = 1; i < records.length; i++) {
      expect(records[i].seq, records[i - 1].seq + 1);
    }
  }, timeout: const Timeout(Duration(seconds: 40)));
}
