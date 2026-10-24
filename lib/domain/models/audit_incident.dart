import '../verification/chain_verifier.dart';

/// A signed record rejected before it could enter an instrument's history.
final class AuditIncident {
  const AuditIncident({
    required this.instrumentId,
    required this.sequence,
    required this.observedAt,
    required this.failure,
    required this.rawRecord,
  });

  /// Instrument whose active session received the record.
  final String instrumentId;

  /// Sequence number claimed by the rejected record.
  final int sequence;

  /// Local app time when verification rejected the record.
  final DateTime observedAt;

  /// Verification rule that rejected the record.
  final ChainFailure failure;

  /// Original JSON retained for inspection, outside the signed history.
  final String rawRecord;
}
