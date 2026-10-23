import 'dart:io';

import 'package:aelos/data/seed/seed_loader.dart';
import 'package:aelos/domain/models/condition_status.dart';
import 'package:aelos/domain/thresholds/alert.dart';
import 'package:aelos/domain/thresholds/threshold_config.dart';
import 'package:aelos/domain/thresholds/threshold_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// The seeded history must give the alerts feed something believable to show.
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
        profile: ThresholdProfile(yearMade: i.yearMade, hasCrackRepairs: i.crackRepairs),
        year: seed.endTime.year,
      );
      alerts[i.id] = engine.evaluate(s.records).alerts;
      // ignore: avoid_print
      for (final a in alerts[i.id]!) print('${i.id} ${a.time.toIso8601String()} ${a.severity.name} ${a.title} — ${a.why}');
    }

    final violin = alerts['violin-mittenwald']!;
    expect(violin.where((a) => a.rule == ThresholdRule.impact), hasLength(1));
    expect(violin.any((a) => a.rule == ThresholdRule.humidityRate), isTrue,
        reason: 'the drying spell trips the tighter pre-1926 rate limit');
    expect(
      alerts['cello-mirecourt']!.any((a) => a.rule == ThresholdRule.impact && a.severity == ConditionStatus.actNow),
      isTrue,
    );
    expect(alerts['viola-cremona']!.any((a) => a.rule == ThresholdRule.freeFall), isTrue);
  });
}
