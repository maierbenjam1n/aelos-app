import 'dart:typed_data';


import '../../domain/models/sensor_record.dart';
import '../../domain/verification/chain_verifier.dart';

/// What a sensor has persisted between runs (docs/ble-protocol.md 5.3): the
/// last sequence number, the last record's hash, and its stored records.
///
/// Lets a `MockSensorConnection` continue an existing chain, such as the
/// seeded history of a demo instrument.
final class MockChainState {
  /// [lastHash] is SHA-256 of the full form of record [lastSeq], i.e. `prev`
  /// of the next record. [records] are optional, but must be contiguous and
  /// end at [lastSeq]; only these can be replayed by `sync`.
  MockChainState({
    required this.lastSeq,
    required List<int> lastHash,
    List<SensorRecord> records = const [],
  }) : lastHash = Uint8List.fromList(lastHash),
       records = List.unmodifiable(records) {
    if (lastSeq < 0 || lastHash.length != 32) {
      throw ArgumentError('lastSeq must be >= 0 and lastHash 32 bytes');
    }
    if (lastSeq == 0 && lastHash.any((b) => b != 0)) {
      throw ArgumentError('An empty chain has a zero lastHash');
    }
    if (records.isEmpty) return;
    for (final (i, record) in records.indexed) {
      if (record.seq != lastSeq - records.length + 1 + i) {
        throw ArgumentError('records must be contiguous and end at lastSeq');
      }
    }
    final expected = recordHash(records.last.json);
    for (var i = 0; i < 32; i++) {
      if (expected[i] != lastHash[i]) {
        throw ArgumentError('lastHash does not match the last record');
      }
    }
  }

  /// A new sensor: no records, `prev` of record 1 is 32 zero bytes.
  factory MockChainState.fresh() =>
      MockChainState(lastSeq: 0, lastHash: Uint8List(32));

  /// Continues after [records] (contiguous, ascending), hashing the last one.
  factory MockChainState.fromRecords(List<SensorRecord> records) =>
      records.isEmpty
      ? MockChainState.fresh()
      : MockChainState(
          lastSeq: records.last.seq,
          lastHash: recordHash(records.last.json),
          records: records,
        );

  final int lastSeq;
  final Uint8List lastHash;
  final List<SensorRecord> records;

  /// Lowest sequence number a `sync` can replay.
  int get firstStoredSeq => records.isEmpty ? lastSeq + 1 : records.first.seq;
}
