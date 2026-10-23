import '../models/sensor_record.dart';

/// Min, max and mean of the readings in one time bucket, in tenths.
final class ReadingBucket {
  const ReadingBucket({
    required this.start,
    required this.count,
    required this.minTenthsCelsius,
    required this.maxTenthsCelsius,
    required this.meanTenthsCelsius,
    required this.minTenthsHumidity,
    required this.maxTenthsHumidity,
    required this.meanTenthsHumidity,
  });

  /// Start of the bucket, aligned to multiples of the bucket size since the
  /// epoch (UTC).
  final DateTime start;
  final int count;
  final int minTenthsCelsius;
  final int maxTenthsCelsius;
  final double meanTenthsCelsius;
  final int minTenthsHumidity;
  final int maxTenthsHumidity;
  final double meanTenthsHumidity;
}

/// Groups the `r` records of [records] into [bucket]-sized buckets for
/// charts. Empty buckets are left out; draw gaps with `findReadingGaps`.
List<ReadingBucket> downsampleReadings(
  Iterable<SensorRecord> records,
  Duration bucket,
) {
  final size = bucket.inMilliseconds;
  if (size <= 0) throw ArgumentError.value(bucket, 'bucket');
  final groups = <int, _Acc>{};
  for (final r in records) {
    final t = r.tenthsCelsius;
    final h = r.tenthsHumidity;
    if (r.kind != RecordKind.reading || t == null || h == null) continue;
    final ms = r.time.millisecondsSinceEpoch;
    // Floor division so pre-1970 times still land in the right bucket.
    final key = (ms - ms % size) ~/ size;
    groups.putIfAbsent(key, _Acc.new).add(t, h);
  }
  final keys = groups.keys.toList()..sort();
  return [
    for (final k in keys)
      groups[k]!.toBucket(
        DateTime.fromMillisecondsSinceEpoch(k * size, isUtc: true),
      ),
  ];
}

final class _Acc {
  int count = 0;
  int minT = 0, maxT = 0, sumT = 0;
  int minH = 0, maxH = 0, sumH = 0;

  void add(int t, int h) {
    if (count == 0) {
      minT = maxT = t;
      minH = maxH = h;
    } else {
      if (t < minT) minT = t;
      if (t > maxT) maxT = t;
      if (h < minH) minH = h;
      if (h > maxH) maxH = h;
    }
    sumT += t;
    sumH += h;
    count++;
  }

  ReadingBucket toBucket(DateTime start) => ReadingBucket(
    start: start,
    count: count,
    minTenthsCelsius: minT,
    maxTenthsCelsius: maxT,
    meanTenthsCelsius: sumT / count,
    minTenthsHumidity: minH,
    maxTenthsHumidity: maxH,
    meanTenthsHumidity: sumH / count,
  );
}
