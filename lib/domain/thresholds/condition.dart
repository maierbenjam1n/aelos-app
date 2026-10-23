import '../models/condition_status.dart';
import 'alert.dart';
import 'threshold_config.dart';

/// The instrument's status now: the worst of the latest reading's band
/// severity and any rate, impact or free-fall alert within
/// [ThresholdConfig.statusWindow] (6 h) before [now].
///
/// Band alerts don't linger: once the reading is back in band, so is the
/// status. Pass only alerts the owner hasn't dismissed.
ConditionStatus currentStatus({
  required ThresholdConfig config,
  required DateTime now,
  int? tenthsHumidity,
  int? tenthsCelsius,
  Iterable<Alert> alerts = const [],
}) {
  var status = ConditionStatus.calm;
  void raise(ConditionStatus s) {
    if (s.index > status.index) status = s;
  }

  if (tenthsHumidity != null) {
    raise(config.humidityBand.statusOf(tenthsHumidity));
  }
  if (tenthsCelsius != null) {
    raise(config.temperatureBand.statusOf(tenthsCelsius));
  }
  final since = now.subtract(config.statusWindow);
  for (final a in alerts) {
    if (a.rule == ThresholdRule.humidityBand ||
        a.rule == ThresholdRule.temperatureBand) {
      continue;
    }
    if (!a.time.isBefore(since) && !a.time.isAfter(now)) raise(a.severity);
  }
  return status;
}
