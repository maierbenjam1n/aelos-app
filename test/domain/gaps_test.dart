import 'package:aelos/domain/history/downsample.dart';
import 'package:aelos/domain/history/gaps.dart';
import 'package:aelos/domain/models/sensor_record.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime.utc(2026, 10, 24);
var _seq = 0;

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

SensorRecord impact(Duration at) => SensorRecord(
  seq: ++_seq,
  time: t0.add(at),
  kind: RecordKind.impact,
  signature: '',
  json: const {},
  raw: '',
  tenthsG: 40,
);

Duration min(int m) => Duration(minutes: m);

void main() {
  setUp(() => _seq = 0);

  test('finds an injected gap in 10-minute history', () {
    // Two days at 600 s, with readings from 10:00 to 13:00 on day one missing.
    final records = [
      for (var i = 0; i < 288; i++)
        if (i <= 60 || i >= 78) reading(min(10 * i)),
    ];
    expect(findReadingGaps(records), [
      ReadingGap(start: t0.add(min(600)), end: t0.add(min(780))),
    ]);
    expect(findReadingGaps(records).single.duration, const Duration(hours: 3));
  });

  test('a spacing of exactly 3× the interval is not a gap', () {
    final times = [
      for (var i = 0; i < 10; i++) t0.add(min(10 * i)),
      t0.add(min(90 + 30)),
      t0.add(min(120 + 31)),
    ];
    expect(findGaps(times), [
      ReadingGap(start: t0.add(min(120)), end: t0.add(min(151))),
    ]);
  });

  test('impacts do not fill a gap; unsorted input is fine', () {
    final records = [
      for (var i = 0; i < 6; i++) reading(min(10 * i)),
      impact(min(80)),
      for (var i = 12; i < 18; i++) reading(min(10 * i)),
    ].reversed;
    expect(findReadingGaps(records), [
      ReadingGap(start: t0.add(min(50)), end: t0.add(min(120))),
    ]);
  });

  test('works on 2-second live data', () {
    final times = [
      for (var s = 0; s < 120; s += 2) t0.add(Duration(seconds: s)),
      for (var s = 130; s < 200; s += 2) t0.add(Duration(seconds: s)),
    ];
    expect(findGaps(times), [
      ReadingGap(
        start: t0.add(const Duration(seconds: 118)),
        end: t0.add(const Duration(seconds: 130)),
      ),
    ]);
  });

  test('too few readings, or an explicit interval', () {
    expect(findGaps([t0, t0.add(min(600))]), isEmpty);
    expect(
      findGaps([t0, t0.add(min(600))], typicalInterval: min(10)),
      hasLength(1),
    );
  });

  test('downsamples into min/max/mean buckets', () {
    final records = [
      for (var i = 0; i < 12; i++) reading(min(10 * i), h: 400 + i, t: 200 - i),
      impact(min(5)),
    ];
    final buckets = downsampleReadings(records, const Duration(hours: 1));
    expect(buckets.map((b) => b.start), [t0, t0.add(const Duration(hours: 1))]);
    expect(buckets.first.count, 6);
    expect(buckets.first.minTenthsHumidity, 400);
    expect(buckets.first.maxTenthsHumidity, 405);
    expect(buckets.first.meanTenthsHumidity, 402.5);
    expect(buckets.last.minTenthsCelsius, 189);
    expect(buckets.last.maxTenthsCelsius, 194);
  });
}
