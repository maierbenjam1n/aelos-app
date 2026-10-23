import '../models/condition_status.dart';
import 'alert.dart';
import 'threshold_config.dart';

/// Alerts of one kind within a replay (e.g. all impacts, or all dry spells).
final class ReplayGroup {
  const ReplayGroup({
    required this.rule,
    required this.direction,
    required this.alerts,
  });

  final ThresholdRule rule;

  /// Below/above for bands (dry vs. humid spell); null otherwise.
  final AlertDirection? direction;
  final List<Alert> alerts;

  int get count => alerts.length;

  /// The most severe alert, ties broken by the largest measured value.
  Alert get worst => alerts.reduce(
    (a, b) =>
        b.severity.index > a.severity.index ||
            (b.severity == a.severity && b.measured > a.measured)
        ? b
        : a,
  );

  /// Count phrase for the headline, e.g. "2 impacts" or "a dry spell".
  String get phrase {
    final (one, many) = switch ((rule, direction)) {
      (ThresholdRule.impact, _) => ('an impact', 'impacts'),
      (ThresholdRule.freeFall, _) => ('a drop', 'drops'),
      (ThresholdRule.humidityBand, AlertDirection.below) => (
        'a dry spell',
        'dry spells',
      ),
      (ThresholdRule.humidityBand, _) => ('a humid spell', 'humid spells'),
      (ThresholdRule.temperatureBand, AlertDirection.below) => (
        'a cold spell',
        'cold spells',
      ),
      (ThresholdRule.temperatureBand, _) => ('a warm spell', 'warm spells'),
      (ThresholdRule.humidityRate, _) => (
        'a quick humidity change',
        'quick humidity changes',
      ),
      (ThresholdRule.temperatureRate, _) => (
        'a quick temperature change',
        'quick temperature changes',
      ),
    };
    return count == 1 ? one : '$count $many';
  }
}

/// One "While you were away" card and notification for a replayed batch.
final class ReplaySummary {
  const ReplaySummary({
    required this.instrumentId,
    required this.groups,
    required this.severity,
    required this.start,
    required this.end,
  });

  final String instrumentId;

  /// Most severe first, then impacts and drops before climate.
  final List<ReplayGroup> groups;

  /// Worst severity in the batch.
  final ConditionStatus severity;

  /// Time of the first and last alert.
  final DateTime start;
  final DateTime end;

  int get alertCount => groups.fold(0, (n, g) => n + g.count);

  /// Count per rule, e.g. `{impact: 2, humidityBand: 1}`.
  Map<ThresholdRule, int> get countsByRule {
    final counts = <ThresholdRule, int>{};
    for (final g in groups) {
      counts.update(g.rule, (n) => n + g.count, ifAbsent: () => g.count);
    }
    return counts;
  }

  /// e.g. "2 impacts and a dry spell while you were away".
  String get headline {
    final phrases = [for (final g in groups) g.phrase];
    final listed = phrases.length > 3
        ? [...phrases.take(2), '${phrases.length - 2} other kinds of event']
        : phrases;
    final joined = listed.length == 1
        ? listed.single
        : '${listed.take(listed.length - 1).join(', ')} and ${listed.last}';
    final text = '$joined while you were away';
    return text[0].toUpperCase() + text.substring(1);
  }

  /// One line per group for the card, using the worst alert's reason.
  List<String> get lines => [for (final g in groups) g.worst.why];

  /// Replaces itself rather than stacking, like [Alert.id].
  String get id => '$instrumentId:replay';

  /// [id] as a notification id.
  int get notificationId => stableNotificationId(id);
}

const _ruleOrder = [
  ThresholdRule.freeFall,
  ThresholdRule.impact,
  ThresholdRule.humidityBand,
  ThresholdRule.humidityRate,
  ThresholdRule.temperatureBand,
  ThresholdRule.temperatureRate,
];

/// Collapses the alerts from a replayed batch into one summary; null when
/// there are none.
ReplaySummary? summarizeReplay(Iterable<Alert> alerts) {
  final list = alerts.toList();
  if (list.isEmpty) return null;
  final byKey = <(ThresholdRule, AlertDirection?), List<Alert>>{};
  for (final a in list) {
    // Rate alerts group regardless of direction; bands split dry vs. humid.
    final banded =
        a.rule == ThresholdRule.humidityBand ||
        a.rule == ThresholdRule.temperatureBand;
    byKey.putIfAbsent((a.rule, banded ? a.direction : null), () => []).add(a);
  }
  final groups =
      [
        for (final e in byKey.entries)
          ReplayGroup(rule: e.key.$1, direction: e.key.$2, alerts: e.value),
      ]..sort((a, b) {
        final bySeverity = b.worst.severity.index - a.worst.severity.index;
        if (bySeverity != 0) return bySeverity;
        return _ruleOrder.indexOf(a.rule) - _ruleOrder.indexOf(b.rule);
      });
  final times = list.map((a) => a.time).toList()..sort();
  return ReplaySummary(
    instrumentId: list.first.instrumentId,
    groups: groups,
    severity: groups.first.worst.severity,
    start: times.first,
    end: times.last,
  );
}
