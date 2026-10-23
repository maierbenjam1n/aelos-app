import '../models/sensor_record.dart';

/// A stretch with no readings, between the last reading before it and the
/// first one after it.
final class ReadingGap {
  const ReadingGap({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is ReadingGap && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ReadingGap($start – $end)';
}

/// Gaps in the `r` records of [records]: spacings longer than [factor] times
/// the typical interval (the median spacing, unless [typicalInterval] is
/// given). Sorted by time; needs at least three readings to infer an
/// interval.
List<ReadingGap> findReadingGaps(
  Iterable<SensorRecord> records, {
  double factor = 3,
  Duration? typicalInterval,
}) => findGaps(
  records.where((r) => r.kind == RecordKind.reading).map((r) => r.time),
  factor: factor,
  typicalInterval: typicalInterval,
);

/// [findReadingGaps] for plain timestamps.
List<ReadingGap> findGaps(
  Iterable<DateTime> times, {
  double factor = 3,
  Duration? typicalInterval,
}) {
  final sorted = times.toList()..sort();
  if (sorted.length < 2) return const [];
  final spacings = [
    for (var i = 1; i < sorted.length; i++)
      sorted[i].difference(sorted[i - 1]).inMilliseconds,
  ];
  final int typical;
  if (typicalInterval != null) {
    typical = typicalInterval.inMilliseconds;
  } else {
    // Two readings give one spacing, which can't be compared to anything.
    if (spacings.length < 2) return const [];
    typical = _median(spacings);
  }
  if (typical <= 0) return const [];
  final threshold = typical * factor;
  return [
    for (var i = 0; i < spacings.length; i++)
      if (spacings[i] > threshold)
        ReadingGap(start: sorted[i], end: sorted[i + 1]),
  ];
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : ((sorted[mid - 1] + sorted[mid]) / 2).round();
}
