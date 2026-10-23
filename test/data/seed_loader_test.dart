import 'dart:convert';
import 'dart:io';

import 'package:aelos/data/seed/seed_loader.dart';
import 'package:aelos/domain/models/instrument.dart';
import 'package:aelos/domain/models/sensor_record.dart';
import 'package:aelos/domain/verification/chain_verifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads assets straight from the repo, independent of the asset build.
final class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Seed seed;
  late Duration loadTime;

  setUpAll(() async {
    final watch = Stopwatch()..start();
    seed = await SeedLoader(bundle: _DiskBundle()).load();
    loadTime = watch.elapsed;
  });

  SeededInstrument byId(String id) =>
      seed.instruments.firstWhere((s) => s.instrument.id == id);

  test('loads three instruments with 30 days of records, quickly', () {
    expect(seed.instruments.map((s) => s.instrument.id), [
      'violin-mittenwald',
      'cello-mirecourt',
      'viola-cremona',
    ]);
    expect(seed.endTime, DateTime.utc(2026, 10, 24, 8));

    final total = seed.instruments.fold(0, (n, s) => n + s.records.length);
    expect(total, greaterThan(12000));
    expect(loadTime, lessThan(const Duration(seconds: 1)));

    for (final s in seed.instruments) {
      final records = s.records;
      expect(records.first.kind, RecordKind.boot);
      expect(records.first.seq, 1);
      expect(records.last.seq, records.length);
      final span = records.last.time.difference(records.first.time);
      expect(span.inDays, 29);
      expect(seed.endTime.difference(records.last.time).inMinutes, lessThan(15));
      final readings = records.where((r) => r.kind == RecordKind.reading);
      expect(readings.length, greaterThan(4200));
      expect(records.first.raw, startsWith('{"k":"b","s":1,"sig":"'));
    }
  });

  test('instrument profiles round-trip and match the brief', () {
    final violin = byId('violin-mittenwald').instrument;
    expect(violin.name, 'Violin, Mittenwald 1890');
    expect(violin.type, InstrumentType.violin);
    expect(violin.yearMade, lessThan(1926));
    expect(violin.photo, 'assets/photos/violin.jpg');

    final cello = byId('cello-mirecourt').instrument;
    expect(cello.type, InstrumentType.cello);
    expect(cello.dateLabel, 'c. 1860');
    expect(cello.crackRepairs, isTrue);
    expect(cello.crackRepairNote, isNotEmpty);

    for (final s in seed.instruments) {
      final i = s.instrument;
      expect(Instrument.fromJson(i.toJson()), i);
      expect(File(i.photo!).existsSync(), isTrue, reason: i.photo);
    }
    final keys = seed.instruments.map((s) => s.instrument.sensorPublicKey);
    expect(keys.toSet(), hasLength(3));
  });

  test("the violin's sensor uses the test key", () {
    final testKey = _json('test/vectors/test_key.json');
    final violin = byId('violin-mittenwald').instrument;
    expect(violin.sensorPublicKey, testKey['public_key']);
    expect(violin.sensorId, testKey['device_id']);
  });

  test('violin has one gap followed by a boot, an impact and a drying spell',
      () {
    final records = byId('violin-mittenwald').records;
    final gaps = <int>[];
    SensorRecord? previous;
    for (final (i, r) in records.indexed) {
      if (r.kind != RecordKind.reading) continue;
      if (previous != null &&
          r.time.difference(previous.time) > const Duration(minutes: 30)) {
        gaps.add(i);
      }
      previous = r;
    }
    expect(gaps, hasLength(1));
    expect(records[gaps.single - 1].kind, RecordKind.boot);
    expect(records.where((r) => r.kind == RecordKind.boot), hasLength(2));

    final impacts = records.where((r) => r.kind == RecordKind.impact);
    expect(impacts.map((r) => r.peakG), [3.4]);

    final driest = records
        .where((r) => r.kind == RecordKind.reading)
        .map((r) => r.humidity!)
        .reduce((a, b) => a < b ? a : b);
    expect(driest, inInclusiveRange(35.0, 38.5));
  });

  test('cello and viola carry the other events', () {
    final cello = byId('cello-mirecourt').records;
    expect(
      cello.where((r) => r.kind == RecordKind.impact).map((r) => r.peakG),
      [6.8],
    );

    final viola = byId('viola-cremona').records;
    final fall = viola.singleWhere((r) => r.kind == RecordKind.freeFall);
    expect(fall.freeFallMs, greaterThanOrEqualTo(150));
    expect(viola[viola.indexOf(fall) + 1].kind, RecordKind.impact);

    for (final s in [cello, viola]) {
      expect(s.where((r) => r.kind == RecordKind.boot), hasLength(1));
    }
  });

  test('climate stays in the demo ranges outside the drying spell', () {
    for (final s in seed.instruments) {
      for (final r in s.records.where((r) => r.kind == RecordKind.reading)) {
        expect(r.celsius, inInclusiveRange(17.5, 25.5));
        expect(r.humidity, inInclusiveRange(35.0, 52.5));
      }
    }
  });

  for (final id in ['violin-mittenwald', 'cello-mirecourt', 'viola-cremona']) {
    test(
      'chain of $id verifies',
      () async {
        final s = byId(id);
        final result = await verifyChain(
          [for (final r in s.records) r.json],
          publicKey: base64Decode(s.instrument.sensorPublicKey),
          isolates: 4,
        );
        expect(result.isValid, isTrue, reason: '${result.reason}');
        expect(result.count, s.records.length);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }

  test('assets are registered in pubspec and load through rootBundle',
      () async {
    final fromBundle = await SeedLoader().load();
    expect(
      fromBundle.instruments.map((s) => s.records.length),
      seed.instruments.map((s) => s.records.length),
    );
    for (final s in fromBundle.instruments) {
      final photo = await rootBundle.load(s.instrument.photo!);
      expect(photo.lengthInBytes, greaterThan(10000));
    }
  });
}
