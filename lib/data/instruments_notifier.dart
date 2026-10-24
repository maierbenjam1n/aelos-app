import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/audit_incident.dart';
import '../domain/models/condition_status.dart';
import '../domain/models/instrument.dart';
import '../domain/models/sensor_record.dart';
import '../domain/thresholds/alert.dart';
import '../domain/thresholds/condition.dart';
import '../domain/thresholds/threshold_config.dart';
import '../domain/thresholds/threshold_engine.dart';
import 'instrument_data.dart';
import 'seed/seed_loader.dart';

final seedProvider = FutureProvider<Seed>((ref) => SeedLoader().load());

final thresholdConfigProvider = FutureProvider<ThresholdConfig>(
  (ref) async => ThresholdConfig.parse(
    await rootBundle.loadString('assets/config/thresholds.json'),
  ),
);

/// When the app started; the seed's end is shown as this moment.
final appStartProvider = Provider<DateTime>((ref) => DateTime.now().toUtc());

final instrumentsProvider =
    AsyncNotifierProvider<InstrumentsNotifier, List<InstrumentData>>(
      InstrumentsNotifier.new,
    );

/// One instrument by id, or null while loading.
final instrumentProvider = Provider.family<InstrumentData?, String>(
  (ref, id) => ref
      .watch(instrumentsProvider)
      .value
      ?.where((i) => i.id == id)
      .firstOrNull,
);

/// The instruments and their histories, kept in memory.
class InstrumentsNotifier extends AsyncNotifier<List<InstrumentData>> {
  late ThresholdConfig _config;

  @override
  Future<List<InstrumentData>> build() async {
    final seed = await ref.watch(seedProvider.future);
    _config = await ref.watch(thresholdConfigProvider.future);
    final offset = ref.watch(appStartProvider).difference(seed.endTime);

    final instruments = <InstrumentData>[];
    for (final s in seed.instruments) {
      final i = s.instrument;
      final engine = _engine(
        i.id,
        i.yearMade,
        i.crackRepairs,
        seed.endTime.year,
      );
      final empty = InstrumentData(
        instrument: i,
        records: const [],
        alerts: const [],
        status: ConditionStatus.calm,
        thresholdState: ThresholdState.initial(),
        displayOffset: offset,
        tighterLimitsReason: engine.tighterLimitsReason,
      );
      instruments.add(
        _evaluate(
          engine,
          base: empty,
          newRecords: s.records,
          seedTimeNow: seed.endTime,
        ).$1,
      );
    }
    return instruments;
  }

  ThresholdEngine _engine(
    String id,
    int? yearMade,
    bool crackRepairs,
    int year,
  ) => ThresholdEngine(
    config: _config,
    instrumentId: id,
    profile: ThresholdProfile(
      yearMade: yearMade,
      hasCrackRepairs: crackRepairs,
    ),
    year: year,
  );

  (InstrumentData, List<Alert>) _evaluate(
    ThresholdEngine engine, {
    required InstrumentData base,
    required List<SensorRecord> newRecords,
    required DateTime seedTimeNow,
  }) {
    final result = engine.evaluate(newRecords, base.thresholdState);
    final records = [...base.records, ...newRecords];
    final alerts = [...base.alerts, ...result.alerts];
    final updated = base.copyWith(
      records: records,
      alerts: alerts,
      thresholdState: result.state,
    );
    final latest = updated.latestReading;
    return (
      updated.copyWith(
        status: currentStatus(
          config: _config,
          now: seedTimeNow,
          tenthsHumidity: latest?.tenthsHumidity,
          tenthsCelsius: latest?.tenthsCelsius,
          alerts: alerts,
        ),
      ),
      result.alerts,
    );
  }

  /// Adds verified records to [instrumentId]'s history and returns the alerts
  /// they raised.
  List<Alert> append(String instrumentId, List<SensorRecord> records) {
    final current = state.value;
    if (current == null || records.isEmpty) return const [];
    final index = current.indexWhere((i) => i.id == instrumentId);
    if (index < 0) return const [];
    final data = current[index];
    final i = data.instrument;
    final (updated, alerts) = _evaluate(
      _engine(i.id, i.yearMade, i.crackRepairs, data.sensorNow.year),
      base: data,
      newRecords: records,
      seedTimeNow: data.sensorNow,
    );
    state = AsyncData([...current]..[index] = updated);
    return alerts;
  }

  /// Retains a rejected sensor record outside the signed history for review.
  void appendIntegrityIncident(AuditIncident incident) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere(
      (item) => item.id == incident.instrumentId,
    );
    if (index < 0) return;
    final data = current[index];
    final alreadyRecorded = data.integrityIncidents.any(
      (existing) =>
          existing.sequence == incident.sequence &&
          existing.failure == incident.failure &&
          existing.rawRecord == incident.rawRecord,
    );
    if (alreadyRecorded) return;
    state = AsyncData(
      [...current]
        ..[index] = data.copyWith(
          integrityIncidents: [...data.integrityIncidents, incident],
        ),
    );
  }

  /// Adds a newly paired instrument to this session's in-memory collection.
  InstrumentData register(Instrument instrument, {Uint8List? photoBytes}) {
    final current = state.value;
    if (current == null) throw StateError('The collection is still loading');
    if (current.any((item) => item.id == instrument.id)) {
      throw StateError('An instrument with this name is already registered');
    }
    final linked = current.where(
      (item) => item.instrument.sensorId == instrument.sensorId,
    );
    if (linked.isNotEmpty) {
      throw StateError(
        'This sensor is already linked to ${linked.first.instrument.name}',
      );
    }

    final now = DateTime.now().toUtc();
    final engine = _engine(
      instrument.id,
      instrument.yearMade,
      instrument.crackRepairs,
      now.year,
    );
    final data = InstrumentData(
      instrument: instrument,
      records: const [],
      alerts: const [],
      status: ConditionStatus.calm,
      thresholdState: ThresholdState.initial(),
      displayOffset: Duration.zero,
      tighterLimitsReason: engine.tighterLimitsReason,
      photoBytes: photoBytes,
    );
    state = AsyncData([...current, data]);
    return data;
  }
}
