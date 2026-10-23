import 'dart:io';

import 'package:aelos/data/seed/seed_loader.dart';
import 'package:aelos/domain/models/condition_status.dart';
import 'package:aelos/domain/thresholds/alert.dart';
import 'package:aelos/domain/thresholds/threshold_config.dart';
import 'package:aelos/domain/thresholds/threshold_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seeded history must give the alerts feed something believable to show:
/// a few calm, distinct alerts, never a flood.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seeded histories produce the expected alerts', () async {
    final seed = await SeedLoader().load();
    final config = ThresholdConfig.parse(
      File('assets/config/thresholds.json').readAsStringSync(),
    );
    final alerts = <String, List<Alert>>{};
    for (final s in seed.instruments) {
      final i = s.instrument;
      final engine = ThresholdEngine(
        config: config,
        instrumentId: i.id,
        profile: ThresholdProfile(
          yearMade: i.yearMade,
          hasCrackRepairs: i.crackRepairs,
        ),
        year: seed.endTime.year,
      );
      alerts[i.id] = engine.evaluate(s.records).alerts;
      for (final a in alerts[i.id]!) {
        // ignore: avoid_print
        print(
          '${i.id} ${a.time.toIso8601String()} ${a.severity.name} '
          '${a.title} — ${a.why}',
        );
      }
    }

    int count(List<Alert> list, ThresholdRule rule) =>
        list.where((a) => a.rule == rule).length;

    final violin = alerts['violin-mittenwald']!;
    expect(violin.length, lessThanOrEqualTo(5));
    expect(count(violin, ThresholdRule.impact), 1);
    expect(
      count(violin, ThresholdRule.humidityRate),
      1,
      reason: 'the drying spell trips the tighter pre-1926 rate limit once',
    );
    expect(count(violin, ThresholdRule.humidityBand), lessThanOrEqualTo(1));
    expect(
      violin.where((a) => a.rule == ThresholdRule.humidityRate).single.title,
      'Humidity is falling quickly',
    );

    final cello = alerts['cello-mirecourt']!;
    expect(
      cello.any(
        (a) =>
            a.rule == ThresholdRule.impact &&
            a.severity == ConditionStatus.actNow,
      ),
      isTrue,
    );
    final viola = alerts['viola-cremona']!;
    expect(viola.any((a) => a.rule == ThresholdRule.freeFall), isTrue);
    expect(cello.length + viola.length, lessThanOrEqualTo(6));
  });
}
