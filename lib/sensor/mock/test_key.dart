import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

/// Private seed of the public TEST key (`test/vectors/test_key.json`), shared
/// by the vectors, the seed data and the mock. Never use it on a real device.
final Uint8List testKeySeed = Uint8List.fromList(
  const DartSha256().hashSync(utf8.encode('aelos test key - TEST ONLY')).bytes,
);

/// Device ID of [testKeySeed]'s public key (`device_id` in test/vectors/test_key.json).
const testDeviceId = '1AFB';

/// Deterministic test-only signing seed for a newly paired mock sensor.
Uint8List registrationTestKeySeed(int index) => Uint8List.fromList(
  const DartSha256()
      .hashSync(utf8.encode('aelos registration sensor $index - TEST ONLY'))
      .bytes,
);
