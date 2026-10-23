import 'dart:convert';
import 'dart:io';

import 'package:aelos/domain/verification/canonical_json.dart';
import 'package:aelos/domain/verification/chain_verifier.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _vector(String name) =>
    jsonDecode(File('test/vectors/$name.json').readAsStringSync())
        as Map<String, Object?>;

List<int> _hex(String hex) => [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];

String _toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('canonical form matches vectors byte for byte', () {
    final cases = (_vector('canonical')['cases']! as List<Object?>)
        .cast<Map<String, Object?>>();

    for (final (i, c) in cases.indexed) {
      test('record ${i + 1}', () {
        final record = jsonDecode(c['input']! as String) as Map<String, Object?>;
        final canonical = canonicalBytes(record);
        final full = canonicalBytes(record, includeSig: true);

        expect(utf8.decode(canonical), c['canonical']);
        expect(utf8.decode(full), c['canonical_with_sig']);
        expect(
          _toHex([..._hex(c['prev_hex']! as String), ...canonical]),
          c['signed_message_hex'],
        );
        expect(_toHex(const DartSha256().hashSync(full).bytes), c['hash_hex']);
      });
    }
  });

  for (final isolates in [1, 3]) {
    group('chain verification on $isolates isolate(s) matches vectors', () {
      for (final name in [
        'chain_valid',
        'chain_partial',
        'chain_edited',
        'chain_deleted',
        'chain_reordered',
        'chain_wrong_key',
      ]) {
        test(name, () async {
          final v = _vector(name);
          final expected = v['expected']! as Map<String, Object?>;

          final result = await verifyChain(
            (v['records']! as List<Object?>).cast<Map<String, Object?>>(),
            publicKey: base64Decode(v['public_key']! as String),
            prevOfFirst: _hex(v['prev_of_first']! as String),
            isolates: isolates,
          );

          expect(result.isValid ? 'valid' : 'invalid', expected['status']);
          expect(result.failedAtIndex, expected['failed_at_index']);
          expect(result.failedAtSeq, expected['failed_at_seq']);
          expect(result.reason?.name, expected['reason']);
        });
      }

      test('pinpoints a tampered record at any position', () async {
        final v = _vector('chain_valid');
        final publicKey = base64Decode(v['public_key']! as String);
        final valid =
            (v['records']! as List<Object?>).cast<Map<String, Object?>>();

        for (var tampered = 0; tampered < valid.length; tampered++) {
          final records = [for (final r in valid) {...r}];
          records[tampered]['ts'] = (records[tampered]['ts']! as int) + 1;

          final result = await verifyChain(
            records,
            publicKey: publicKey,
            isolates: isolates,
          );

          expect(result.failedAtIndex, tampered);
          expect(result.reason, ChainFailure.signature);
        }
      });
    });
  }

  test('rejects a record with an extra key as malformed', () async {
    final v = _vector('chain_valid');
    final records = (v['records']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map((r) => {...r})
        .toList();
    records[2]['x'] = 1;

    final result = await verifyChain(
      records,
      publicKey: base64Decode(v['public_key']! as String),
    );

    expect(result.reason, ChainFailure.malformed);
    expect(result.failedAtSeq, 3);
  });

  test('incremental verifier exposes prev for the next bundle', () async {
    final v = _vector('chain_valid');
    final records =
        (v['records']! as List<Object?>).cast<Map<String, Object?>>();
    final verifier =
        ChainVerifier(publicKey: base64Decode(v['public_key']! as String));

    for (final r in records.take(3)) {
      expect(await verifier.add(r), isNull);
    }

    expect(verifier.lastSeq, 3);
    expect(_toHex(verifier.prev), _vector('chain_partial')['prev_of_first']);
  });

  test('a verifier continuing a stored chain enforces the next seq', () async {
    final v = _vector('chain_valid');
    final records =
        (v['records']! as List<Object?>).cast<Map<String, Object?>>();
    final publicKey = base64Decode(v['public_key']! as String);
    ChainVerifier continuing() => ChainVerifier(
          publicKey: publicKey,
          prevOfFirst: recordHash(records[2]),
          lastSeq: 3,
        );

    expect(await continuing().add(records[3]), isNull);
    expect(await continuing().add(records[4]), ChainFailure.sequence);
  });
}
