import 'dart:convert';

import '../models/condition_status.dart';

/// The six rules of the threshold engine; [key] matches `thresholds.json`.
enum ThresholdRule {
  humidityBand('humidity_band'),
  humidityRate('humidity_rate'),
  temperatureBand('temperature_band'),
  temperatureRate('temperature_rate'),
  impact('impact'),
  freeFall('free_fall');

  const ThresholdRule(this.key);

  final String key;
}

/// Allowed range for a reading, in protocol units (tenths). Limits are
/// exclusive: a value exactly on a limit is still inside the band.
final class BandRule {
  const BandRule({
    required this.warningBelow,
    required this.warningAbove,
    this.criticalBelow,
    this.criticalAbove,
  });

  factory BandRule.fromJson(Map<String, Object?> json) => BandRule(
    warningBelow: _tenths(json['warning_below'])!,
    warningAbove: _tenths(json['warning_above'])!,
    criticalBelow: _tenths(json['critical_below']),
    criticalAbove: _tenths(json['critical_above']),
  );

  final int warningBelow;
  final int warningAbove;
  final int? criticalBelow;
  final int? criticalAbove;

  /// Severity of [value] (tenths): calm inside the band.
  ConditionStatus statusOf(int value) {
    if (criticalBelow != null && value < criticalBelow!) {
      return ConditionStatus.actNow;
    }
    if (criticalAbove != null && value > criticalAbove!) {
      return ConditionStatus.actNow;
    }
    if (value < warningBelow || value > warningAbove) {
      return ConditionStatus.attention;
    }
    return ConditionStatus.calm;
  }
}

/// One rate window: more than [maxChange] tenths of change within [window].
final class RateWindow {
  const RateWindow({required this.window, required this.maxChange});

  factory RateWindow.fromJson(Map<String, Object?> json) => RateWindow(
    window: Duration(
      milliseconds: ((json['hours']! as num) * Duration.millisecondsPerHour)
          .round(),
    ),
    maxChange: _tenths(json['max_change'])!,
  );

  final Duration window;

  /// Largest allowed change within [window], in tenths.
  final int maxChange;
}

/// Rate-of-change rule over one or more windows.
final class RateRule {
  const RateRule({
    required this.windows,
    this.severity = ConditionStatus.attention,
    this.tighterLimits = false,
  });

  factory RateRule.fromJson(Map<String, Object?> json) => RateRule(
    windows: (json['windows']! as List<Object?>)
        .map((w) => RateWindow.fromJson(w! as Map<String, Object?>))
        .toList(),
    severity: _severity(json['severity']),
    tighterLimits: json['tighter_limits'] as bool? ?? false,
  );

  final List<RateWindow> windows;
  final ConditionStatus severity;

  /// Whether [TighterLimits.humidityRateFactor] applies to this rule.
  final bool tighterLimits;
}

/// Threshold for an event record (impact peak g in tenths, free fall in ms).
/// Values at or above a threshold trigger it.
final class EventRule {
  const EventRule({this.warningAt, this.criticalAt});

  factory EventRule.fromJson(Map<String, Object?> json, {required int scale}) =>
      EventRule(
        warningAt: _scaled(json['warning_at'], scale),
        criticalAt: _scaled(json['critical_at'], scale),
      );

  final int? warningAt;
  final int? criticalAt;

  /// Severity of [value]: calm below every threshold.
  ConditionStatus statusOf(int value) {
    if (criticalAt != null && value >= criticalAt!) {
      return ConditionStatus.actNow;
    }
    if (warningAt != null && value >= warningAt!) {
      return ConditionStatus.attention;
    }
    return ConditionStatus.calm;
  }
}

/// Instrument facts the engine needs. Built from the instrument profile.
final class ThresholdProfile {
  const ThresholdProfile({this.yearMade, this.hasCrackRepairs = false});

  final int? yearMade;
  final bool hasCrackRepairs;
}

/// Profile modifier: rate rules flagged `tighter_limits` are multiplied by
/// [humidityRateFactor] for old or repaired instruments.
final class TighterLimits {
  const TighterLimits({
    required this.olderThanYears,
    required this.crackRepairs,
    required this.humidityRateFactor,
  });

  factory TighterLimits.fromJson(Map<String, Object?> json) => TighterLimits(
    olderThanYears: json['older_than_years']! as int,
    crackRepairs: json['crack_repairs'] as bool? ?? true,
    humidityRateFactor: (json['humidity_rate_factor']! as num).toDouble(),
  );

  /// Age in years above which limits tighten (100 means made before 1926 in
  /// 2026).
  final int olderThanYears;

  /// Whether past crack repairs tighten limits.
  final bool crackRepairs;
  final double humidityRateFactor;

  bool _isOld(ThresholdProfile profile, int year) =>
      profile.yearMade != null && year - profile.yearMade! > olderThanYears;

  bool _isRepaired(ThresholdProfile profile) =>
      crackRepairs && profile.hasCrackRepairs;

  /// Whether the modifier applies to [profile] in calendar [year].
  bool appliesTo(ThresholdProfile profile, {required int year}) =>
      _isOld(profile, year) || _isRepaired(profile);

  /// Note for the detail screen, or null when limits are not tightened.
  String? reasonFor(ThresholdProfile profile, {required int year}) {
    final old = _isOld(profile, year);
    final repaired = _isRepaired(profile);
    if (old && repaired) {
      return 'Tighter limits applied: instrument over $olderThanYears years '
          'old, with past crack repairs';
    }
    if (old) {
      return 'Tighter limits applied: instrument over $olderThanYears years '
          'old';
    }
    if (repaired) return 'Tighter limits applied: past crack repairs';
    return null;
  }
}

/// All threshold rules, parsed from `assets/config/thresholds.json`.
final class ThresholdConfig {
  const ThresholdConfig({
    required this.humidityBand,
    required this.humidityRate,
    required this.temperatureBand,
    required this.temperatureRate,
    required this.impact,
    required this.freeFall,
    required this.tighterLimits,
    this.debounce = const Duration(minutes: 30),
    this.statusWindow = const Duration(hours: 6),
  });

  factory ThresholdConfig.fromJson(Map<String, Object?> json) {
    final rules = json['rules']! as Map<String, Object?>;
    Map<String, Object?> rule(ThresholdRule r) =>
        rules[r.key]! as Map<String, Object?>;
    return ThresholdConfig(
      humidityBand: BandRule.fromJson(rule(ThresholdRule.humidityBand)),
      humidityRate: RateRule.fromJson(rule(ThresholdRule.humidityRate)),
      temperatureBand: BandRule.fromJson(rule(ThresholdRule.temperatureBand)),
      temperatureRate: RateRule.fromJson(rule(ThresholdRule.temperatureRate)),
      impact: EventRule.fromJson(rule(ThresholdRule.impact), scale: 10),
      freeFall: EventRule.fromJson(rule(ThresholdRule.freeFall), scale: 1),
      tighterLimits: TighterLimits.fromJson(
        json['tighter_limits']! as Map<String, Object?>,
      ),
      debounce: Duration(minutes: json['debounce_minutes'] as int? ?? 30),
      statusWindow: Duration(hours: json['status_window_hours'] as int? ?? 6),
    );
  }

  /// Parses the contents of `thresholds.json`.
  factory ThresholdConfig.parse(String source) =>
      ThresholdConfig.fromJson(jsonDecode(source) as Map<String, Object?>);

  final BandRule humidityBand;
  final RateRule humidityRate;
  final BandRule temperatureBand;
  final RateRule temperatureRate;
  final EventRule impact;
  final EventRule freeFall;
  final TighterLimits tighterLimits;

  /// Minimum time between two alerts of the same band or rate rule.
  final Duration debounce;

  /// How long a rate, impact or free-fall alert keeps the status raised.
  final Duration statusWindow;
}

int? _scaled(Object? value, int scale) =>
    value == null ? null : ((value as num) * scale).round();

int? _tenths(Object? value) => _scaled(value, 10);

ConditionStatus _severity(Object? value) => switch (value) {
  'critical' => ConditionStatus.actNow,
  'warning' || null => ConditionStatus.attention,
  _ => throw FormatException('Unknown severity', value),
};
