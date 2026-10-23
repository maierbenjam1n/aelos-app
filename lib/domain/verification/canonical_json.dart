import 'dart:convert';
import 'dart:typed_data';

/// Canonical form of a record (docs/ble-protocol.md 5.2): sorted keys, no
/// whitespace, UTF-8, `sig` excluded unless [includeSig].
///
/// Throws [FormatException] for values a record can't contain (anything but
/// integers and strings).
Uint8List canonicalBytes(
  Map<String, Object?> record, {
  bool includeSig = false,
}) {
  final keys = [
    for (final key in record.keys)
      if (includeSig || key != 'sig') key,
  ]..sort();
  final out = StringBuffer('{');
  for (final (i, key) in keys.indexed) {
    if (i > 0) out.write(',');
    out
      ..write(jsonEncode(key))
      ..write(':')
      ..write(_encodeValue(record[key]));
  }
  out.write('}');
  return utf8.encode(out.toString());
}

String _encodeValue(Object? value) => switch (value) {
      // On the web, JSON numbers are doubles; integral ones still pass `is int`.
      final int v => '$v',
      final String v => jsonEncode(v),
      _ => throw FormatException('Not a record value', value),
    };
