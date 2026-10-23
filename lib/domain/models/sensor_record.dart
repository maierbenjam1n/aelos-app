import 'dart:convert';

/// Record kind as transmitted in the `k` field (docs/ble-protocol.md 5.1).
enum RecordKind {
  reading('r'),
  impact('i'),
  freeFall('f'),
  boot('b');

  const RecordKind(this.code);

  final String code;

  static RecordKind? fromCode(Object? code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

/// One signed record from the sensor's hash chain.
final class SensorRecord {
  const SensorRecord({
    required this.seq,
    required this.time,
    required this.kind,
    required this.signature,
    required this.json,
    required this.raw,
    this.tenthsCelsius,
    this.tenthsHumidity,
    this.tenthsG,
    this.freeFallMs,
  });

  /// Parses one `records` payload. Throws [FormatException] if it isn't a
  /// record; full validation is the verifier's job.
  factory SensorRecord.parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('Record is not a JSON object', raw);
    }
    // The WebSocket transport adds a `ch` key that is not part of the record.
    final json = Map<String, Object?>.of(decoded)..remove('ch');
    final kind = RecordKind.fromCode(json['k']);
    final seq = json['s'];
    final ts = json['ts'];
    final sig = json['sig'];
    if (kind == null || seq is! int || ts is! int || sig is! String) {
      throw FormatException('Missing record fields', raw);
    }
    return SensorRecord(
      seq: seq,
      time: DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true),
      kind: kind,
      signature: sig,
      json: json,
      raw: decoded.containsKey('ch') ? jsonEncode(json) : raw,
      tenthsCelsius: json['t'] as int?,
      tenthsHumidity: json['h'] as int?,
      tenthsG: json['g'] as int?,
      freeFallMs: json['ms'] as int?,
    );
  }

  final int seq;
  final DateTime time;
  final RecordKind kind;
  final String signature;

  /// Decoded fields exactly as received; the verifier canonicalizes these.
  final Map<String, Object?> json;

  /// The record as one JSON line, for `records.jsonl` in exported bundles.
  final String raw;

  final int? tenthsCelsius;
  final int? tenthsHumidity;
  final int? tenthsG;
  final int? freeFallMs;

  double? get celsius => tenthsCelsius == null ? null : tenthsCelsius! / 10;
  double? get humidity => tenthsHumidity == null ? null : tenthsHumidity! / 10;
  double? get peakG => tenthsG == null ? null : tenthsG! / 10;
}
