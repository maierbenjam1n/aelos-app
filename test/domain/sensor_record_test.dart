import 'dart:convert';
import 'dart:io';

import 'package:aelos/domain/models/sensor_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses every record in chain_valid', () {
    final vector = jsonDecode(
      File('test/vectors/chain_valid.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final records = (vector['records']! as List<Object?>)
        .map((r) => SensorRecord.parse(jsonEncode(r)))
        .toList();

    expect(records.map((r) => r.seq), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(records[1].humidity, 48.2);
    expect(records[4].peakG, 7.2);
    expect(records[6].freeFallMs, 310);
    expect(records[7].celsius, -1.5);
  });

  test('strips the WebSocket ch key', () {
    final record = SensorRecord.parse(
      '{"ch":"records","s":1,"ts":1761250000,"k":"b","sig":"x"}',
    );
    expect(record.json.containsKey('ch'), isFalse);
    expect(record.raw, '{"s":1,"ts":1761250000,"k":"b","sig":"x"}');
  });
}
