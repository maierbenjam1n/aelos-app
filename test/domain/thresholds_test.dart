import 'dart:io';

import 'package:aelos/domain/models/condition_status.dart';
import 'package:aelos/domain/models/sensor_record.dart';
import 'package:aelos/domain/thresholds/alert.dart';
import 'package:aelos/domain/thresholds/condition.dart';
import 'package:aelos/domain/thresholds/replay_summary.dart';
import 'package:aelos/domain/thresholds/threshold_config.dart';
import 'package:aelos/domain/thresholds/threshold_engine.dart';
import 'package:flutter_test/flutter_test.dart';

final config = ThresholdConfig.parse(
  File('assets/config/thresholds.json').readAsStringSync(),
);
final t0 = DateTime.utc(2026, 10, 24, 12);
var _seq = 0;

Duration min(int m) => Duration(minutes: m);

/// Unsigned test records; the engine must not look at signatures.
SensorRecord reading(Duration at, {int h = 480, int t = 210}) => SensorRecord(
  seq: ++_seq,
  time: t0.add(at),
  kind: RecordKind.reading,
  signature: '',
  json: const {},
  raw: '',
  tenthsCelsius: t,
  tenthsHumidity: h,
);

SensorRecord impact(Duration at, int tenthsG) => SensorRecord(
  seq: ++_seq,
  time: t0.add(at),
  kind: RecordKind.impact,
  signature: '',
  json: const {},
  raw: '',
  tenthsG: tenthsG,
);

SensorRecord freeFall(Duration at, int ms) => SensorRecord(
  seq: ++_seq,
  time: t0.add(at),
  kind: RecordKind.freeFall,
  signature: '',
  json: const {},
  raw: '',
  freeFallMs: ms,
);

ThresholdEngine engine({ThresholdProfile profile = const ThresholdProfile()}) =>
    ThresholdEngine(
      config: config,
      instrumentId: 'violin',
      profile: profile,
      year: 2026,
    );

List<Alert> run(
  List<SensorRecord> records, {
  ThresholdProfile profile = const ThresholdProfile(),
}) => engine(profile: profile).evaluate(records).alerts;

const old = ThresholdProfile(yearMade: 1890);

/// Readings 10 minutes apart from [t0].
List<SensorRecord> series(List<int> humidity) => [
  for (var i = 0; i < humidity.length; i++)
    reading(min(10 * i), h: humidity[i]),
];

List<Alert> rateAlerts(
  List<SensorRecord> records, {
  ThresholdProfile profile = const ThresholdProfile(),
}) => run(
  records,
  profile: profile,
).where((a) => a.rule == ThresholdRule.humidityRate).toList();

void main() {
  setUp(() => _seq = 0);

  test('parses thresholds.json into tenths', () {
    expect(config.humidityBand.warningBelow, 400);
    expect(config.humidityBand.warningAbove, 600);
    expect(config.humidityBand.criticalBelow, 350);
    expect(config.humidityBand.criticalAbove, 700);
    expect(config.humidityRate.windows.map((w) => w.window), [
      const Duration(hours: 1),
      const Duration(hours: 24),
    ]);
    expect(config.humidityRate.windows.map((w) => w.maxChange), [50, 100]);
    expect(config.humidityRate.tighterLimits, isTrue);
    expect(config.temperatureBand.criticalBelow, isNull);
    expect(config.temperatureRate.windows.single.maxChange, 50);
    expect(config.temperatureRate.tighterLimits, isFalse);
    expect(config.impact.warningAt, 30);
    expect(config.impact.criticalAt, 60);
    expect(config.freeFall.warningAt, isNull);
    expect(config.freeFall.criticalAt, 150);
    expect(config.tighterLimits.humidityRateFactor, 0.7);
    expect(config.debounce, min(30));
  });

  group('humidity band', () {
    for (final (h, severity) in [
      (400, null),
      (399, ConditionStatus.attention),
      (600, null),
      (601, ConditionStatus.attention),
      (350, ConditionStatus.attention),
      (349, ConditionStatus.actNow),
      (700, ConditionStatus.attention),
      (701, ConditionStatus.actNow),
    ]) {
      test('${h / 10} % → ${severity?.name ?? 'no alert'}', () {
        final alerts = run([reading(Duration.zero, h: h)]);
        expect(alerts.map((a) => a.severity), [?severity]);
        if (severity != null) {
          expect(alerts.single.rule, ThresholdRule.humidityBand);
          expect(alerts.single.measured, h);
        }
      });
    }

    test('says why and what to do', () {
      final alert = run([reading(Duration.zero, h: 378)]).single;
      expect(alert.title, 'Humidity is low');
      expect(alert.why, 'Humidity is 37.8 %, below the 40–60 % range.');
      expect(alert.whatToDo, 'Keep the case closed; check the humidifier.');
      expect(alert.direction, AlertDirection.below);
      expect(alert.limit, 400);
    });

    test('a continuing violation fires once', () {
      final alerts = run([
        for (var i = 0; i < 12; i++) reading(min(10 * i), h: 380),
      ]);
      expect(alerts, hasLength(1));
    });

    test('escalation to critical fires despite the debounce', () {
      final alerts = run([
        reading(Duration.zero, h: 390),
        reading(min(5), h: 380),
        reading(min(10), h: 340),
      ]);
      expect(alerts.map((a) => a.severity), [
        ConditionStatus.attention,
        ConditionStatus.actNow,
      ]);
      expect(alerts.last.title, 'Humidity is very low');
      expect(alerts.last.limit, 350);
    });
  });

  group('humidity rate', () {
    test('exactly 5 % in an hour does not fire, 5.1 % does', () {
      expect(
        run([reading(Duration.zero, h: 480), reading(min(60), h: 530)]),
        isEmpty,
      );
      _seq = 0;
      final alert = run([
        reading(Duration.zero, h: 480),
        reading(min(60), h: 531),
      ]).single;
      expect(alert.rule, ThresholdRule.humidityRate);
      expect(alert.severity, ConditionStatus.attention);
      expect(alert.direction, AlertDirection.rising);
      expect(alert.measured, 51);
      expect(alert.seqs, [1, 2]);
      expect(alert.why, 'Humidity rose 5.1 % in the last hour.');
    });

    test('a change spread over more than an hour is not an hourly rate', () {
      expect(
        run([reading(Duration.zero, h: 480), reading(min(61), h: 540)]),
        isEmpty,
      );
    });

    test('10-minute readings: a steady fall fires once it exceeds 5 %', () {
      final alerts = run([
        for (var i = 0; i <= 6; i++) reading(min(10 * i), h: 480 - 10 * i),
      ]);
      final alert = alerts.single;
      expect(alert.time, t0.add(min(60)));
      expect(alert.why, 'Humidity fell 6.0 % in the last hour.');
      expect(alert.whatToDo, 'Keep the case closed; check the humidifier.');
      expect(alert.seqs, [1, 7]);
    });

    test('2-second live data: same rule, based on timestamps', () {
      // 0.1 % per minute: crosses 5 % after 51 minutes.
      final records = [
        for (var s = 0; s <= 3600; s += 2)
          reading(Duration(seconds: s), h: 480 - s ~/ 60),
      ];
      final alerts = run(records);
      expect(alerts.first.time, t0.add(min(51)));
      expect(alerts.first.why, 'Humidity fell 5.1 % in the last hour.');
      // Still falling, but the next alert waits 30 minutes.
      expect(alerts, hasLength(1));
    });

    test('2-second noise does not add up to a rate', () {
      final records = [
        for (var s = 0; s <= 3600; s += 2)
          reading(Duration(seconds: s), h: 480 + ((s ~/ 2).isEven ? 1 : 0)),
      ];
      expect(run(records), isEmpty);
    });

    test('more than 10 % in 24 hours fires', () {
      // 11 % over 20 hours: never fast enough for the hourly window.
      final alerts = run([
        for (var i = 0; i <= 120; i++)
          reading(min(10 * i), h: 520 - i * 110 ~/ 120),
      ]);
      // One episode, one alert, although the window stays over the limit.
      final alert = alerts.single;
      expect(alert.rule, ThresholdRule.humidityRate);
      expect(alert.time, t0.add(min(10 * 111)));
      expect(alert.why, 'Humidity fell 10.1 % in the last 24 hours.');
      expect(alert.title, 'Humidity is falling quickly');
    });

    test('×0.7 for instruments over 100 years old', () {
      final records = [
        reading(Duration.zero, h: 480),
        reading(min(60), h: 444),
      ];
      expect(run(records), isEmpty);
      _seq = 0;
      final alert = run(records, profile: old).single;
      expect(alert.limit, 35);
      expect(
        alert.why,
        'Humidity fell 3.6 % in the last hour. '
        'The limit for this instrument is 3.5 %.',
      );
    });

    test('×0.7 limit is exclusive and also applies to 24 hours', () {
      expect(
        run([
          reading(Duration.zero, h: 480),
          reading(min(60), h: 445),
        ], profile: old),
        isEmpty,
      );
      final alerts = run([
        for (var i = 0; i <= 120; i++)
          reading(min(10 * i), h: 520 - i * 80 ~/ 120),
      ], profile: const ThresholdProfile(hasCrackRepairs: true));
      expect(alerts.first.limit, 70);
      expect(alerts.first.measured, 71);
    });

    test('temperature rate is not tightened', () {
      expect(
        run([
          reading(Duration.zero, t: 200),
          reading(min(60), t: 240),
        ], profile: old),
        isEmpty,
      );
    });
  });

  group('tighter limits', () {
    test('apply before 1926 or with crack repairs', () {
      expect(engine().tighterLimits, isFalse);
      expect(engine().tighterLimitsReason, isNull);
      const made1926 = ThresholdProfile(yearMade: 1926);
      expect(engine(profile: made1926).tighterLimits, isFalse);
      expect(engine(profile: old).tighterLimits, isTrue);
      expect(
        engine(profile: old).tighterLimitsReason,
        'Tighter limits applied: instrument over 100 years old',
      );
      expect(
        engine(profile: const ThresholdProfile(hasCrackRepairs: true))
            .tighterLimitsReason,
        'Tighter limits applied: past crack repairs',
      );
      expect(
        engine(
          profile: const ThresholdProfile(
            yearMade: 1700,
            hasCrackRepairs: true,
          ),
        ).tighterLimitsReason,
        'Tighter limits applied: instrument over 100 years old, '
        'with past crack repairs',
      );
    });
  });

  group('temperature', () {
    for (final (t, fires) in [
      (150, false),
      (149, true),
      (300, false),
      (301, true),
      (-50, true),
    ]) {
      test('${t / 10} °C → ${fires ? 'warning' : 'no alert'}', () {
        final alerts = run([reading(Duration.zero, t: t)]);
        expect(alerts.map((a) => (a.rule, a.severity)), [
          if (fires) (ThresholdRule.temperatureBand, ConditionStatus.attention),
        ]);
      });
    }

    test('rate: 5 °C in an hour does not fire, 5.1 °C does', () {
      expect(
        run([reading(Duration.zero, t: 210), reading(min(60), t: 260)]),
        isEmpty,
      );
      final alert = run([
        reading(Duration.zero, t: 210),
        reading(min(30), t: 261),
      ]).single;
      expect(alert.rule, ThresholdRule.temperatureRate);
      expect(alert.why, 'Temperature rose 5.1 °C in the last hour.');
    });
  });

  group('events', () {
    for (final (g, severity) in [
      (29, null),
      (30, ConditionStatus.attention),
      (59, ConditionStatus.attention),
      (60, ConditionStatus.actNow),
    ]) {
      test('impact ${g / 10} g → ${severity?.name ?? 'no alert'}', () {
        final alerts = run([impact(Duration.zero, g)]);
        expect(alerts.map((a) => a.severity), [?severity]);
      });
    }

    for (final (ms, severity) in [(149, null), (150, ConditionStatus.actNow)]) {
      test('free fall $ms ms → ${severity?.name ?? 'no alert'}', () {
        final alerts = run([freeFall(Duration.zero, ms)]);
        expect(alerts.map((a) => a.severity), [?severity]);
      });
    }

    test('impacts are not debounced and carry their seq', () {
      final alerts = run([
        impact(Duration.zero, 72),
        impact(const Duration(seconds: 5), 41),
      ]);
      expect(alerts.map((a) => a.seqs), [
        [1],
        [2],
      ]);
      expect(alerts.first.title, 'Strong impact recorded');
      expect(alerts.first.why, 'The sensor recorded a 7.2 g impact.');
      expect(alerts.last.title, 'Impact recorded');
    });

    test('free fall text gives the drop height', () {
      final alert = run([freeFall(Duration.zero, 310)]).single;
      expect(
        alert.why,
        'The case was in free fall for 310 ms, '
        'a drop of about 47 cm.',
      );
    });
  });

  group('episodes', () {
    test('band: violations 10 minutes apart give one alert', () {
      final alerts = run([
        reading(Duration.zero, h: 390),
        reading(min(5), h: 410),
        reading(min(10), h: 390),
      ]);
      expect(alerts, hasLength(1));
    });

    test('band: 30 minutes back in band ends the episode', () {
      final alerts = run([
        reading(Duration.zero, h: 390),
        reading(min(5), h: 410),
        reading(min(35), h: 410),
        reading(min(40), h: 390),
      ]);
      expect(alerts.map((a) => a.time), [t0, t0.add(min(40))]);
      expect(alerts.map((a) => a.id).toSet(), {'violin:humidity_band'});
    });

    test('band: 20 minutes back in band does not', () {
      final alerts = run([
        reading(Duration.zero, h: 390),
        reading(min(10), h: 410),
        reading(min(20), h: 410),
        reading(min(30), h: 390),
      ]);
      expect(alerts, hasLength(1));
    });

    test('band: crossing to the other side is a new alert', () {
      final alerts = run([
        reading(Duration.zero, h: 390, t: 140),
        reading(min(40), h: 390, t: 310),
      ]).where((a) => a.rule == ThresholdRule.temperatureBand);
      expect(alerts.map((a) => a.direction), [
        AlertDirection.below,
        AlertDirection.above,
      ]);
    });

    test('rate: 3 hours of continuous fast change give one alert', () {
      final tenMinutes = rateAlerts(
        series([for (var i = 0; i <= 18; i++) 600 - 10 * i]),
      );
      expect(tenMinutes.map((a) => a.time), [t0.add(min(60))]);
      _seq = 0;
      final live = rateAlerts([
        for (var s = 0; s <= 3 * 3600; s += 2)
          reading(Duration(seconds: s), h: 600 - s ~/ 60),
      ]);
      expect(live.map((a) => a.time), [t0.add(min(51))]);
    });

    test('rate: drop, 2 hours stable, drop again give two alerts', () {
      final alerts = rateAlerts(
        series([
          for (var i = 0; i <= 6; i++) 520 - 10 * i,
          for (var i = 0; i < 12; i++) 460,
          for (var i = 1; i <= 6; i++) 460 - 10 * i,
        ]),
      );
      expect(alerts.map((a) => a.direction), [
        AlertDirection.falling,
        AlertDirection.falling,
      ]);
      expect(alerts.map((a) => a.time), [
        t0.add(min(60)),
        t0.add(min(10 * 24)),
      ]);
    });

    test('rate: a second drop alerts while the 24 h window is still over', () {
      // Tighter limits (3.5 %/h, 7 %/24 h): the first drop of 8 % keeps the
      // 24 h window over its limit for the rest of the test.
      final alerts = rateAlerts(
        series([
          for (var i = 0; i <= 8; i++) 560 - 10 * i,
          for (var i = 0; i < 12; i++) 480,
          for (var i = 1; i <= 5; i++) 480 - 10 * i,
        ]),
        profile: old,
      );
      expect(alerts, hasLength(2));
      expect(
        alerts.last.why,
        startsWith('Humidity fell 4.0 % in the last hour.'),
      );
    });

    test('rate: a recovery right after a drop does not alert again', () {
      final alerts = rateAlerts(
        series([
          for (var i = 0; i <= 6; i++) 520 - 10 * i,
          for (var i = 1; i <= 6; i++) 460 + 10 * i,
          for (var i = 0; i < 24; i++) 520,
        ]),
        profile: old,
      );
      expect(alerts.map((a) => a.direction), [AlertDirection.falling]);
    });

    test('rate: a rise after the episode has ended is a new episode', () {
      final alerts = rateAlerts(
        series([
          for (var i = 0; i <= 6; i++) 520 - 10 * i,
          for (var i = 0; i < 12; i++) 460,
          for (var i = 1; i <= 6; i++) 460 + 10 * i,
        ]),
      );
      expect(alerts.map((a) => a.direction), [
        AlertDirection.falling,
        AlertDirection.rising,
      ]);
      expect(alerts.last.title, 'Humidity is rising quickly');
    });

    test('state carries across calls without being mutated', () {
      final e = engine();
      final first = e.evaluate(
        series([for (var i = 0; i <= 6; i++) 520 - 10 * i]),
      );
      expect(first.alerts, hasLength(1));
      final continued = [reading(min(70), h: 450), reading(min(80), h: 440)];
      expect(e.evaluate(continued, first.state).alerts, isEmpty);
      final later = [
        for (var i = 7; i <= 18; i++) reading(min(10 * i), h: 460),
        for (var i = 1; i <= 6; i++)
          reading(min(180 + 10 * i), h: 460 - 10 * i),
      ];
      final a = e.evaluate(later, first.state).alerts;
      final b = e.evaluate(later, first.state).alerts;
      expect(a.map((x) => x.time), [t0.add(min(240))]);
      expect(b.map((x) => x.time), a.map((x) => x.time));
    });

    test('a clock moving backwards restarts the rate windows', () {
      final alerts = run([
        reading(min(60), h: 480),
        reading(Duration.zero, h: 540),
      ]);
      expect(alerts, isEmpty);
    });
  });

  test('alert ids repeat per instrument and rule', () {
    final alerts = run([impact(Duration.zero, 40), impact(min(1), 70)]);
    expect(alerts.first.id, alerts.last.id);
    expect(alerts.first.notificationId, alerts.last.notificationId);
    expect(alerts.first.notificationId, isNonNegative);
    final drop = run([freeFall(Duration.zero, 200)]).single;
    expect(drop.notificationId, isNot(alerts.first.notificationId));
    expect(stableNotificationId('violin:impact'), alerts.first.notificationId);
  });

  group('replay summary', () {
    test('collapses a batch into one headline', () {
      final alerts = run([
        impact(min(30), 41),
        reading(min(60), h: 420),
        reading(min(120), h: 390),
        impact(min(200), 72),
      ]);
      final summary = summarizeReplay(alerts)!;
      expect(summary.headline, '2 impacts and a dry spell while you were away');
      expect(summary.severity, ConditionStatus.actNow);
      expect(summary.countsByRule, {
        ThresholdRule.impact: 2,
        ThresholdRule.humidityBand: 1,
      });
      expect(summary.alertCount, 3);
      expect(summary.start, t0.add(min(30)));
      expect(summary.end, t0.add(min(200)));
      expect(summary.lines.first, 'The sensor recorded a 7.2 g impact.');
      expect(summary.id, 'violin:replay');
    });

    test('single event and long lists read naturally', () {
      expect(
        summarizeReplay(run([freeFall(Duration.zero, 200)]))!.headline,
        'A drop while you were away',
      );
      final many = run([
        freeFall(Duration.zero, 200),
        impact(min(1), 40),
        reading(min(2), h: 390, t: 140),
        reading(min(3), h: 650, t: 140),
      ]);
      expect(
        summarizeReplay(many)!.headline,
        'A drop, an impact and 3 other kinds of event while you were away',
      );
    });

    test('no alerts, no summary', () {
      expect(summarizeReplay(const []), isNull);
    });
  });

  group('current status', () {
    final now = t0.add(const Duration(hours: 8));
    ConditionStatus status({
      int h = 480,
      int t = 210,
      List<Alert> alerts = const [],
    }) => currentStatus(
      config: config,
      now: now,
      tenthsHumidity: h,
      tenthsCelsius: t,
      alerts: alerts,
    );

    test('follows the latest reading', () {
      expect(status(), ConditionStatus.calm);
      expect(status(h: 390), ConditionStatus.attention);
      expect(status(h: 340), ConditionStatus.actNow);
      expect(status(t: 310), ConditionStatus.attention);
    });

    test('recent rate and event alerts raise it for 6 hours', () {
      final strong = run([impact(const Duration(hours: 7), 70)]);
      expect(status(alerts: strong), ConditionStatus.actNow);
      final earlier = run([impact(const Duration(hours: 1), 70)]);
      expect(status(alerts: earlier), ConditionStatus.calm);
      final rate = run([
        reading(const Duration(hours: 5), h: 480),
        reading(const Duration(hours: 5, minutes: 30), h: 540),
      ]);
      expect(status(alerts: rate), ConditionStatus.attention);
    });

    test('band alerts do not linger once back in band', () {
      final band = run([reading(const Duration(hours: 7), h: 340)]);
      expect(status(alerts: band), ConditionStatus.calm);
    });
  });
}
