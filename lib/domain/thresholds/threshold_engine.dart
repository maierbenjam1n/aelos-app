import 'dart:collection';
import 'dart:math' as math;

import '../models/condition_status.dart';
import '../models/sensor_record.dart';
import 'alert.dart';
import 'threshold_config.dart';

/// Evaluates records against a [ThresholdConfig] for one instrument.
///
/// Pure: all memory between calls lives in the [ThresholdState] passed in
/// and returned, so callers can keep one state per instrument.
final class ThresholdEngine {
  ThresholdEngine({
    required this.config,
    required this.instrumentId,
    this.profile = const ThresholdProfile(),
    int? year,
  }) : year = year ?? DateTime.now().year;

  final ThresholdConfig config;
  final String instrumentId;
  final ThresholdProfile profile;

  /// Calendar year used to decide whether the instrument is "old".
  final int year;

  /// Whether the profile modifier tightens humidity-rate limits.
  bool get tighterLimits => config.tighterLimits.appliesTo(profile, year: year);

  /// "Tighter limits applied: …" for the detail screen, or null.
  String? get tighterLimitsReason =>
      config.tighterLimits.reasonFor(profile, year: year);

  /// Feeds [records] (in arrival order) through every rule and returns the
  /// alerts they raise plus the state to pass to the next call. Signatures
  /// are not checked here.
  ThresholdResult evaluate(
    Iterable<SensorRecord> records, [
    ThresholdState? state,
  ]) {
    final s = state?._copy() ?? ThresholdState.initial();
    final alerts = <Alert>[];
    for (final record in records) {
      switch (record.kind) {
        case RecordKind.reading:
          final h = record.tenthsHumidity;
          final t = record.tenthsCelsius;
          if (h != null) {
            _band(s, alerts, record, _humidity, h);
            _rate(s, alerts, record, _humidity, h);
          }
          if (t != null) {
            _band(s, alerts, record, _temperature, t);
            _rate(s, alerts, record, _temperature, t);
          }
        case RecordKind.impact:
          final g = record.tenthsG;
          if (g != null) _event(alerts, record, ThresholdRule.impact, g);
        case RecordKind.freeFall:
          final ms = record.freeFallMs;
          if (ms != null) _event(alerts, record, ThresholdRule.freeFall, ms);
        case RecordKind.boot:
          break;
      }
    }
    return ThresholdResult(alerts: alerts, state: s);
  }

  static const _humidity = _Metric.humidity;
  static const _temperature = _Metric.temperature;

  void _band(
    ThresholdState s,
    List<Alert> out,
    SensorRecord record,
    _Metric metric,
    int value,
  ) {
    final rule = metric.bandRule;
    final band = metric == _Metric.humidity
        ? config.humidityBand
        : config.temperatureBand;
    final severity = band.statusOf(value);
    final episode = s._episodes[rule];
    if (severity == ConditionStatus.calm) {
      _calm(s, rule, record.time);
      return;
    }
    final direction = value < band.warningBelow
        ? AlertDirection.below
        : AlertDirection.above;
    // One alert per episode: when it starts, crosses to the other side of
    // the band or escalates. Brief returns into the band don't end it.
    final fire =
        episode == null ||
        episode.direction != direction ||
        severity.index > episode.severity.index;
    if (episode == null || episode.direction != direction) {
      s._episodes[rule] = _Episode(direction, severity);
    } else {
      episode
        ..calmSince = null
        ..severity = severity.index > episode.severity.index
            ? severity
            : episode.severity;
    }
    if (!fire || _debounced(s, rule, record.time, severity)) return;
    s._lastAlert[rule] = _Fired(record.time, severity, direction);
    final limit = switch ((direction, severity)) {
      (AlertDirection.below, ConditionStatus.actNow) => band.criticalBelow!,
      (AlertDirection.below, _) => band.warningBelow,
      (_, ConditionStatus.actNow) => band.criticalAbove!,
      _ => band.warningAbove,
    };
    final text = _bandText(metric, band, direction, severity, value);
    out.add(
      Alert(
        instrumentId: instrumentId,
        rule: rule,
        severity: severity,
        time: record.time,
        seqs: [record.seq],
        measured: value,
        limit: limit,
        direction: direction,
        title: text.$1,
        why: text.$2,
        whatToDo: text.$3,
      ),
    );
  }

  void _rate(
    ThresholdState s,
    List<Alert> out,
    SensorRecord record,
    _Metric metric,
    int value,
  ) {
    final rateRule = metric == _Metric.humidity
        ? config.humidityRate
        : config.temperatureRate;
    final windows = s._windows.putIfAbsent(
      metric,
      () => [for (final w in rateRule.windows) _Window(w.window)],
    );
    final rule = metric.rateRule;
    final time = record.time;
    final last = s._lastReading[metric];
    // Clock corrections can move `ts` backwards; start the windows afresh
    // rather than compute a change over a negative span.
    if (last != null && time.isBefore(last)) {
      for (final w in windows) {
        w.clear();
      }
      s._episodes.remove(rule);
      s._horizons.remove(rule);
    }
    s._lastReading[metric] = time;

    final point = _Point(time, value, record.seq);
    final factor = rateRule.tighterLimits && tighterLimits
        ? config.tighterLimits.humidityRateFactor
        : 1.0;
    final violations = <int, _Violation>{};
    for (var i = 0; i < windows.length; i++) {
      final change = windows[i].add(point);
      // Tenths are the sensor's resolution, so round the scaled limit to them.
      final limit = (rateRule.windows[i].maxChange * factor).round();
      if (change.size > limit) {
        violations[i] = _Violation(change, limit, rateRule.windows[i].window);
      }
    }
    if (violations.isEmpty) {
      _calm(s, rule, time);
      return;
    }

    // One excursion gives one alert, whichever window trips first. Each
    // window keeps a horizon: the last time it was violated or reported. A
    // change measured from a reading at or before the horizon is already
    // covered: a fall that continues, the 24 h window catching up with a fall
    // the 1 h window reported, or the 24 h window still spanning a past low
    // after the recovery. While an episode is open, a change in the other
    // direction is the recovery and doesn't alert. A fresh fall after a calm
    // stretch does, even while a 24 h window keeps the episode open.
    final horizons = s._horizons.putIfAbsent(
      rule,
      () => List.filled(windows.length, null),
    );
    final episode = s._episodes[rule]?..calmSince = null;
    int? fresh;
    for (final MapEntry(key: i, value: v) in violations.entries) {
      final horizon = horizons[i];
      if ((episode == null || _direction(v.change) == episode.direction) &&
          (horizon == null || v.change.from.time.isAfter(horizon))) {
        fresh = i;
        break;
      }
    }
    final severity = rateRule.severity;
    final held = fresh != null && _debounced(s, rule, time, severity);
    for (final i in violations.keys) {
      // A capped excursion stays fresh so it can alert once the cap lapses.
      if (!(held && i == fresh)) horizons[i] = time;
    }
    if (fresh == null || held) return;
    horizons.fillRange(0, horizons.length, time);
    final violation = violations[fresh]!;
    final direction = _direction(violation.change);
    s._episodes[rule] ??= _Episode(direction, severity);
    s._lastAlert[rule] = _Fired(time, severity, direction);
    final text = _rateText(metric, violation, tightened: factor != 1.0);
    out.add(
      Alert(
        instrumentId: instrumentId,
        rule: rule,
        severity: severity,
        time: record.time,
        seqs: [
          if (violation.change.from.seq != record.seq)
            violation.change.from.seq,
          record.seq,
        ],
        measured: violation.change.size,
        limit: violation.limit,
        direction: direction,
        title: text.$1,
        why: text.$2,
        whatToDo: text.$3,
      ),
    );
  }

  void _event(
    List<Alert> out,
    SensorRecord record,
    ThresholdRule rule,
    int value,
  ) {
    final eventRule = rule == ThresholdRule.impact
        ? config.impact
        : config.freeFall;
    final severity = eventRule.statusOf(value);
    if (severity == ConditionStatus.calm) return;
    final limit = severity == ConditionStatus.actNow
        ? eventRule.criticalAt!
        : eventRule.warningAt!;
    final text = rule == ThresholdRule.impact
        ? _impactText(value, severity)
        : _freeFallText(value);
    // Events are never debounced: every impact is evidence the owner sees.
    out.add(
      Alert(
        instrumentId: instrumentId,
        rule: rule,
        severity: severity,
        time: record.time,
        seqs: [record.seq],
        measured: value,
        limit: limit,
        title: text.$1,
        why: text.$2,
        whatToDo: text.$3,
      ),
    );
  }

  /// Ends the rule's episode once readings have been within limits for
  /// [ThresholdConfig.debounce].
  void _calm(ThresholdState s, ThresholdRule rule, DateTime time) {
    final episode = s._episodes[rule];
    if (episode == null) return;
    final since = episode.calmSince ??= time;
    if (time.difference(since) >= config.debounce) s._episodes.remove(rule);
  }

  /// Caps alerts of one rule to one per [ThresholdConfig.debounce].
  bool _debounced(
    ThresholdState s,
    ThresholdRule rule,
    DateTime time,
    ConditionStatus severity,
  ) {
    final last = s._lastAlert[rule];
    if (last == null) return false;
    // Escalating to a worse severity is never held back.
    if (severity.index > last.severity.index) return false;
    return time.difference(last.time).abs() < config.debounce;
  }
}

/// Alerts from one [ThresholdEngine.evaluate] call and the state after it.
final class ThresholdResult {
  const ThresholdResult({required this.alerts, required this.state});

  final List<Alert> alerts;
  final ThresholdState state;
}

/// What the engine remembers between calls: recent readings for the rate
/// windows, the last alert per rule (the 30 min cap) and open episodes.
/// Opaque to callers; [ThresholdEngine.evaluate] never mutates its input.
final class ThresholdState {
  ThresholdState.initial();

  final Map<_Metric, List<_Window>> _windows = {};
  final Map<_Metric, DateTime> _lastReading = {};
  final Map<ThresholdRule, _Fired> _lastAlert = {};
  final Map<ThresholdRule, _Episode> _episodes = {};
  final Map<ThresholdRule, List<DateTime?>> _horizons = {};

  ThresholdState _copy() => ThresholdState.initial()
    .._windows.addAll({
      for (final e in _windows.entries)
        e.key: [for (final w in e.value) w.copy()],
    })
    .._lastReading.addAll(_lastReading)
    .._lastAlert.addAll(_lastAlert)
    .._episodes.addAll({
      for (final e in _episodes.entries) e.key: e.value.copy(),
    })
    .._horizons.addAll({
      for (final e in _horizons.entries) e.key: List.of(e.value),
    });
}

enum _Metric {
  humidity(ThresholdRule.humidityBand, ThresholdRule.humidityRate),
  temperature(ThresholdRule.temperatureBand, ThresholdRule.temperatureRate);

  const _Metric(this.bandRule, this.rateRule);

  final ThresholdRule bandRule;
  final ThresholdRule rateRule;
}

final class _Fired {
  const _Fired(this.time, this.severity, this.direction);

  final DateTime time;
  final ConditionStatus severity;
  final AlertDirection direction;
}

/// An ongoing band or rate violation (see [ThresholdEngine._band] and
/// [ThresholdEngine._rate]).
final class _Episode {
  _Episode(this.direction, this.severity);

  final AlertDirection direction;
  ConditionStatus severity;

  /// First reading back within limits, or null while still violated.
  DateTime? calmSince;

  _Episode copy() => _Episode(direction, severity)..calmSince = calmSince;
}

AlertDirection _direction(_Change change) =>
    change.rising ? AlertDirection.rising : AlertDirection.falling;

final class _Point {
  const _Point(this.time, this.value, this.seq);

  final DateTime time;
  final int value;
  final int seq;
}

final class _Change {
  const _Change(this.from, this.size, {required this.rising});

  /// The earlier reading the change is measured from.
  final _Point from;
  final int size;
  final bool rising;
}

final class _Violation {
  const _Violation(this.change, this.limit, this.window);

  final _Change change;
  final int limit;
  final Duration window;
}

/// Sliding min and max over a time window (monotonic deques), so the largest
/// change into the latest reading costs O(1) amortized per reading whether
/// readings come every 2 s or every 10 min.
final class _Window {
  _Window(this.duration);

  final Duration duration;
  final ListQueue<_Point> _min = ListQueue();
  final ListQueue<_Point> _max = ListQueue();

  _Window copy() => _Window(duration)
    .._min.addAll(_min)
    .._max.addAll(_max);

  void clear() {
    _min.clear();
    _max.clear();
  }

  /// Adds [p] and returns the largest change from any reading in the window
  /// to [p].
  _Change add(_Point p) {
    while (_min.isNotEmpty && _min.last.value >= p.value) {
      _min.removeLast();
    }
    _min.addLast(p);
    while (_max.isNotEmpty && _max.last.value <= p.value) {
      _max.removeLast();
    }
    _max.addLast(p);
    final start = p.time.subtract(duration);
    while (_min.first.time.isBefore(start)) {
      _min.removeFirst();
    }
    while (_max.first.time.isBefore(start)) {
      _max.removeFirst();
    }
    final rise = p.value - _min.first.value;
    final fall = _max.first.value - p.value;
    return rise >= fall
        ? _Change(_min.first, rise, rising: true)
        : _Change(_max.first, fall, rising: false);
  }
}

// --- User-facing text. Calm and precise; never claim the app protects the
// instrument. -----------------------------------------------------------------

typedef _Text = (String title, String why, String whatToDo);

/// Tenths as "37.8"; with [trim], whole numbers drop the ".0" ("40").
String _fmt(int tenths, {bool trim = false}) {
  if (trim && tenths % 10 == 0) return '${tenths ~/ 10}';
  return (tenths / 10).toStringAsFixed(1);
}

String _range(BandRule band, String unit) =>
    '${_fmt(band.warningBelow, trim: true)}–'
    '${_fmt(band.warningAbove, trim: true)} $unit';

String _windowPhrase(Duration window) {
  if (window == const Duration(hours: 1)) return 'in the last hour';
  if (window.inMinutes % 60 == 0) return 'in the last ${window.inHours} hours';
  return 'in the last ${window.inMinutes} minutes';
}

_Text _bandText(
  _Metric metric,
  BandRule band,
  AlertDirection direction,
  ConditionStatus severity,
  int value,
) {
  final critical = severity == ConditionStatus.actNow;
  final below = direction == AlertDirection.below;
  if (metric == _Metric.humidity) {
    final where =
        '${critical ? 'well ' : ''}${below ? 'below' : 'above'} '
        'the ${_range(band, '%')} range';
    final why = 'Humidity is ${_fmt(value)} %, $where.';
    if (below) {
      return (
        critical ? 'Humidity is very low' : 'Humidity is low',
        why,
        critical
            ? 'Keep the case closed, refill the humidifier now and keep the '
                  'instrument away from heaters.'
            : 'Keep the case closed; check the humidifier.',
      );
    }
    return (
      critical ? 'Humidity is very high' : 'Humidity is high',
      why,
      critical
          ? 'Take the humidifier out of the case and move the instrument to a '
                'drier room.'
          : 'Check the humidifier is not overfilled and let the case air in a '
                'drier room.',
    );
  }
  final where =
      '${critical ? 'well ' : ''}${below ? 'below' : 'above'} '
      'the ${_range(band, '°C')} range';
  final why = 'Temperature is ${_fmt(value)} °C, $where.';
  if (below) {
    return (
      'It is cold in the case',
      why,
      'Bring the case indoors and let it warm up slowly before you open it.',
    );
  }
  return (
    'It is warm in the case',
    why,
    'Move the case out of the sun and away from heaters or a hot car.',
  );
}

_Text _rateText(_Metric metric, _Violation v, {required bool tightened}) {
  final humidity = metric == _Metric.humidity;
  final unit = humidity ? '%' : '°C';
  final verb = v.change.rising ? 'rose' : 'fell';
  final limitNote = tightened
      ? ' The limit for this instrument is ${_fmt(v.limit)} $unit.'
      : '';
  final why =
      '${humidity ? 'Humidity' : 'Temperature'} $verb '
      '${_fmt(v.change.size)} $unit ${_windowPhrase(v.window)}.$limitNote';
  final trend = v.change.rising ? 'rising' : 'falling';
  if (humidity) {
    return (
      'Humidity is $trend quickly',
      why,
      v.change.rising
          ? 'Keep the case closed and away from damp air; check the '
                'humidifier is not overfilled.'
          : 'Keep the case closed; check the humidifier.',
    );
  }
  return (
    'Temperature is $trend quickly',
    why,
    'Keep the case closed so the instrument can adjust slowly.',
  );
}

_Text _impactText(int tenthsG, ConditionStatus severity) {
  final why = 'The sensor recorded a ${_fmt(tenthsG)} g impact.';
  if (severity == ConditionStatus.actNow) {
    return (
      'Strong impact recorded',
      why,
      'Open the case and check the bridge, soundpost and seams. If anything '
          'has moved, have a luthier look at it.',
    );
  }
  return (
    'Impact recorded',
    why,
    'When convenient, check that the bridge is upright and the seams are '
        'closed.',
  );
}

_Text _freeFallText(int ms) {
  // Drop height from free-fall time: h = g·t²/2.
  final seconds = ms / 1000;
  final cm = (9.81 * seconds * seconds / 2 * 100).round();
  return (
    'Drop recorded',
    'The case was in free fall for $ms ms, a drop of about '
        '${math.max(cm, 1)} cm.',
    'Open the case and check the bridge, soundpost and seams. If anything has '
        'moved or cracked, have a luthier look at it.',
  );
}
