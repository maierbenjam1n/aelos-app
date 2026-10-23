import 'dart:async';

import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/data/instrument_data.dart';
import 'package:aelos/data/instruments_notifier.dart';
import 'package:aelos/data/sensor_session.dart';
import 'package:aelos/domain/models/condition_status.dart';
import 'package:aelos/domain/models/instrument.dart';
import 'package:aelos/domain/thresholds/alert.dart';
import 'package:aelos/domain/thresholds/threshold_config.dart';
import 'package:aelos/domain/thresholds/threshold_engine.dart';
import 'package:aelos/features/impact/alert_host.dart';
import 'package:aelos/features/impact/impact_takeover_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _violin = Instrument(
  id: 'violin-mittenwald',
  name: 'Violin, Mittenwald 1890',
  type: InstrumentType.violin,
  yearMade: 1890,
  topWood: 'Spruce',
  backWood: 'Maple',
  varnish: 'Oil varnish',
  sensorId: '1AFB',
  sensorPublicKey: 'fhiI2SByZBXfx9MAx1+RpbDKd1MWhjk0bZybDneDA4A=',
);

Alert _alert(ThresholdRule rule) => Alert(
      instrumentId: _violin.id,
      rule: rule,
      severity: ConditionStatus.actNow,
      time: DateTime.utc(2026, 10, 24, 12),
      seqs: const [1],
      measured: 72,
      limit: 60,
      title: 'Strong impact recorded',
      why: 'The sensor recorded a 7.2 g impact.',
      whatToDo: 'Check the instrument.',
    );

void main() {
  testWidgets('impacts take over the screen; climate alerts do not', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 1920)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final alerts = StreamController<Alert>();
    addTearDown(alerts.close);
    final opened = <String>[];
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alertEventsProvider.overrideWith((ref) => alerts.stream),
          instrumentProvider.overrideWith(
            (ref, id) => InstrumentData(
              instrument: _violin,
              records: const [],
              alerts: const [],
              status: ConditionStatus.calm,
              thresholdState: ThresholdState.initial(),
              displayOffset: Duration.zero,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AelosTheme.dark,
          navigatorKey: navigatorKey,
          builder: (context, child) => AlertHost(
            navigatorKey: navigatorKey,
            onOpenInstrument: opened.add,
            child: child!,
          ),
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );

    alerts.add(_alert(ThresholdRule.humidityRate));
    await tester.pumpAndSettle();
    expect(find.byType(ImpactTakeoverScreen), findsNothing);

    alerts.add(_alert(ThresholdRule.impact));
    await tester.pumpAndSettle();
    expect(find.byType(ImpactTakeoverScreen), findsOneWidget);
    expect(find.text('Strong impact recorded'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byType(ImpactTakeoverScreen), findsNothing);

    alerts.add(_alert(ThresholdRule.freeFall));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View instrument'));
    await tester.pumpAndSettle();
    expect(find.byType(ImpactTakeoverScreen), findsNothing);
    expect(opened, [_violin.id]);
  });
}
