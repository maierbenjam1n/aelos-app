import '../models/condition_status.dart';
import 'threshold_config.dart';

/// Which side of a limit a band or rate alert is on; null for events.
enum AlertDirection { below, above, falling, rising }

/// One alert from the threshold engine, with the text the app shows.
final class Alert {
  const Alert({
    required this.instrumentId,
    required this.rule,
    required this.severity,
    required this.time,
    required this.seqs,
    required this.measured,
    required this.limit,
    required this.title,
    required this.why,
    required this.whatToDo,
    this.direction,
  });

  final String instrumentId;
  final ThresholdRule rule;

  /// [ConditionStatus.attention] (warning) or [ConditionStatus.actNow].
  final ConditionStatus severity;

  /// Time of the record that triggered the alert.
  final DateTime time;

  /// Sequence numbers of the triggering records (rate alerts: the earlier
  /// extreme, then the latest reading). Empty for unsigned input.
  final List<int> seqs;

  /// Measured value in protocol units: tenths of % RH, °C or g; ms for free
  /// fall. For rate rules, the size of the change.
  final int measured;

  /// The limit that was crossed, in the same units as [measured].
  final int limit;

  final AlertDirection? direction;

  /// Short headline, e.g. "Humidity is changing quickly".
  final String title;

  /// Why it fired, e.g. "Humidity fell 6.2 % in the last hour."
  final String why;

  /// What the owner can do, e.g. "Keep the case closed; check the humidifier."
  final String whatToDo;

  /// Stable per instrument and rule, so a repeat replaces the previous
  /// notification instead of stacking.
  String get id => '$instrumentId:${rule.key}';

  /// [id] as a positive 31-bit int for `flutter_local_notifications`
  /// (FNV-1a, stable across runs unlike `String.hashCode`).
  int get notificationId => stableNotificationId(id);

  @override
  String toString() => 'Alert($id, ${severity.name}, $time, $why)';
}

/// FNV-1a hash of [key], masked to a positive 31-bit int.
int stableNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    // hash * 0x01000193 mod 2^32, split so intermediates stay below 2^53 on
    // the web.
    hash = (hash * 0x193 + ((hash & 0xff) << 24)) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
