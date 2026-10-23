import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/instrument.dart';
import '../../domain/models/sensor_record.dart';

/// One seeded instrument with its signed history in chain order.
final class SeededInstrument {
  const SeededInstrument({required this.instrument, required this.records});

  final Instrument instrument;

  /// Every record from `s = 1`, raw lines kept for export and verification.
  final List<SensorRecord> records;
}

/// The contents of `assets/seed/`.
final class Seed {
  const Seed({required this.endTime, required this.instruments});

  /// The seed's "now" (2026-10-24T08:00Z). Record times are signed and can't
  /// change, so the UI offsets display times by `now - endTime` instead.
  final DateTime endTime;
  final List<SeededInstrument> instruments;
}

/// Loads the pre-signed demo data written by `tools/gen_seed.py`.
final class SeedLoader {
  SeedLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const dir = 'assets/seed';

  final AssetBundle _bundle;

  Future<Seed> load() async {
    final manifest = jsonDecode(
      await _bundle.loadString('$dir/instruments.json', cache: false),
    ) as Map<String, Object?>;
    final instruments = (manifest['instruments']! as List<Object?>)
        .map((e) => Instrument.fromJson(e! as Map<String, Object?>))
        .toList();

    final records = await Future.wait([
      for (final i in instruments) _loadRecords(i.id),
    ]);

    return Seed(
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (manifest['endTs']! as int) * 1000,
        isUtc: true,
      ),
      instruments: [
        for (final (n, instrument) in instruments.indexed)
          SeededInstrument(instrument: instrument, records: records[n]),
      ],
    );
  }

  Future<List<SensorRecord>> _loadRecords(String instrumentId) async {
    final text = await _bundle.loadString(
      '$dir/records_$instrumentId.jsonl',
      cache: false,
    );
    return [
      for (final line in const LineSplitter().convert(text))
        if (line.isNotEmpty) SensorRecord.parse(line),
    ];
  }
}
