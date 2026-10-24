import 'dart:typed_data';

import '../domain/models/condition_status.dart';
import '../domain/models/instrument.dart';
import '../domain/models/sensor_record.dart';
import '../domain/thresholds/alert.dart';
import '../domain/thresholds/threshold_engine.dart';

/// Everything the screens show about one instrument, in protocol units.
final class InstrumentData {
  const InstrumentData({
    required this.instrument,
    required this.records,
    required this.alerts,
    required this.status,
    required this.thresholdState,
    required this.displayOffset,
    this.tighterLimitsReason,
    this.photoBytes,
  });

  final Instrument instrument;

  /// The signed history, oldest first, exactly as received.
  final List<SensorRecord> records;

  /// Every alert the history has produced, oldest first.
  final List<Alert> alerts;
  final ConditionStatus status;
  final ThresholdState thresholdState;

  /// Seeded and mock records are signed in the seed's timeline; adding this
  /// shows them as if the history ended at app start. Zero for real sensors.
  final Duration displayOffset;

  /// E.g. "Tighter limits applied: instrument over 100 years old".
  final String? tighterLimitsReason;

  /// An optional user-selected photo kept in memory for this session.
  final Uint8List? photoBytes;

  String get id => instrument.id;

  SensorRecord? get latestReading {
    for (var i = records.length - 1; i >= 0; i--) {
      if (records[i].kind == RecordKind.reading) return records[i];
    }
    return null;
  }

  /// When the sensor's clock reads [signed], in local display time.
  DateTime displayTime(DateTime signed) => signed.add(displayOffset).toLocal();

  /// "Now" on the sensor's (signed) timeline.
  DateTime get sensorNow => DateTime.now().toUtc().subtract(displayOffset);

  InstrumentData copyWith({
    List<SensorRecord>? records,
    List<Alert>? alerts,
    ConditionStatus? status,
    ThresholdState? thresholdState,
  }) => InstrumentData(
    instrument: instrument,
    records: records ?? this.records,
    alerts: alerts ?? this.alerts,
    status: status ?? this.status,
    thresholdState: thresholdState ?? this.thresholdState,
    displayOffset: displayOffset,
    tighterLimitsReason: tighterLimitsReason,
    photoBytes: photoBytes,
  );
}
