import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import 'canonical_json.dart';

/// Why a record failed verification (docs/ble-protocol.md 7).
enum ChainFailure { malformed, sequence, signature }

/// Outcome of verifying a list of records.
final class ChainResult {
  const ChainResult.valid({required this.count})
      : failedAtIndex = null,
        failedAtSeq = null,
        reason = null;

  const ChainResult.invalid({
    required this.count,
    required int this.failedAtIndex,
    required this.failedAtSeq,
    required ChainFailure this.reason,
  });

  /// Number of records in the list that was verified.
  final int count;
  final int? failedAtIndex;
  final int? failedAtSeq;
  final ChainFailure? reason;

  bool get isValid => reason == null;
}

/// `prev` for the record with `s = 1`.
final zeroPrev = Uint8List(32);

// Pure-Dart implementations: they run in any isolate and on the web without
// platform channels. cryptography_flutter has no Android Ed25519 anyway.
final _ed25519 = DartEd25519();
const _sha256 = DartSha256();

const _requiredKeys = {
  'r': {'s', 'ts', 'k', 't', 'h', 'sig'},
  'i': {'s', 'ts', 'k', 'g', 'sig'},
  'f': {'s', 'ts', 'k', 'ms', 'sig'},
  'b': {'s', 'ts', 'k', 'sig'},
};

/// Verifies records one at a time as they arrive, keeping the chain state
/// between calls.
final class ChainVerifier {
  ChainVerifier({required this._publicKey, List<int>? prevOfFirst})
      : _prev = Uint8List.fromList(prevOfFirst ?? zeroPrev),
        _startsChain = _isZero(prevOfFirst);

  final List<int> _publicKey;
  final bool _startsChain;
  Uint8List _prev;
  int? _lastSeq;

  /// Sequence number of the last record that verified, if any.
  int? get lastSeq => _lastSeq;

  /// Hash of the last verified record: `prev` for the next one, and
  /// `prev_of_first` for a bundle starting after it.
  Uint8List get prev => _prev;

  /// Checks [record] as the next in the chain. Returns null and advances on
  /// success; returns the failure and leaves the state unchanged otherwise.
  Future<ChainFailure?> add(Map<String, Object?> record) async {
    if (!_isWellFormed(record)) return ChainFailure.malformed;
    final seq = record['s']! as int;
    if (seq != _expectedSeq(_lastSeq, seq, startsChain: _startsChain)) {
      return ChainFailure.sequence;
    }
    final ok = await _verify(
      _publicKey,
      _signedMessage(_prev, record),
      _decodeSignature(record),
    );
    if (!ok) return ChainFailure.signature;
    _prev = _hash(record);
    _lastSeq = seq;
    return null;
  }
}

/// Verifies a whole list and reports the first failure in chain order.
///
/// With [isolates] > 1, signature checks are split across that many isolates
/// (not on the web, where `Isolate.run` is unavailable).
Future<ChainResult> verifyChain(
  List<Map<String, Object?>> records, {
  required List<int> publicKey,
  List<int>? prevOfFirst,
  int isolates = 1,
}) async {
  // Sequential pass for everything cheap: shape, sequence and each signed
  // message, which needs the hash of the record before it.
  final startsChain = _isZero(prevOfFirst);
  final messages = <Uint8List>[];
  final signatures = <Uint8List?>[];
  (int, ChainFailure)? cheapFailure;
  var prev = Uint8List.fromList(prevOfFirst ?? zeroPrev);
  int? lastSeq;
  for (final (i, record) in records.indexed) {
    if (!_isWellFormed(record)) {
      cheapFailure = (i, ChainFailure.malformed);
      break;
    }
    final seq = record['s']! as int;
    if (seq != _expectedSeq(lastSeq, seq, startsChain: startsChain)) {
      cheapFailure = (i, ChainFailure.sequence);
      break;
    }
    messages.add(_signedMessage(prev, record));
    signatures.add(_decodeSignature(record));
    prev = _hash(record);
    lastSeq = seq;
  }

  // Signature checks are independent of each other, so they parallelize. Every
  // record needs its own check: a record's hash covers its signature but not
  // its prev, so one valid signature says nothing about earlier records.
  final n = messages.length;
  final workers = _isWeb ? 1 : isolates.clamp(1, n == 0 ? 1 : n);
  final chunk = (n / workers).ceil();
  final firstBad = await Future.wait([
    for (var start = 0; start < n; start += chunk)
      _inIsolate(workers > 1, () async {
        final end = start + chunk < n ? start + chunk : n;
        for (var i = start; i < end; i++) {
          if (!await _verify(publicKey, messages[i], signatures[i])) return i;
        }
        return null;
      }),
  ]);
  final signatureFailure = firstBad.nonNulls.firstOrNull;

  final failure = signatureFailure != null
      ? (signatureFailure, ChainFailure.signature)
      : cheapFailure;
  if (failure == null) return ChainResult.valid(count: records.length);
  final (index, reason) = failure;
  final seq = records[index]['s'];
  return ChainResult.invalid(
    count: records.length,
    failedAtIndex: index,
    failedAtSeq: seq is int ? seq : null,
    reason: reason,
  );
}

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

Future<T> _inIsolate<T>(bool enabled, Future<T> Function() body) =>
    enabled ? Isolate.run(body) : body();

bool _isZero(List<int>? prev) => prev == null || prev.every((b) => b == 0);

int _expectedSeq(int? lastSeq, int seq, {required bool startsChain}) =>
    lastSeq != null ? lastSeq + 1 : (startsChain ? 1 : seq);

Uint8List _signedMessage(Uint8List prev, Map<String, Object?> record) {
  final canonical = canonicalBytes(record);
  return Uint8List(32 + canonical.length)
    ..setAll(0, prev)
    ..setAll(32, canonical);
}

Uint8List _hash(Map<String, Object?> record) => Uint8List.fromList(
      _sha256.hashSync(canonicalBytes(record, includeSig: true)).bytes,
    );

/// Null when `sig` isn't valid base64 of 64 bytes.
Uint8List? _decodeSignature(Map<String, Object?> record) {
  try {
    final bytes = base64Decode(record['sig']! as String);
    return bytes.length == 64 ? bytes : null;
  } on FormatException {
    return null;
  }
}

Future<bool> _verify(
  List<int> publicKey,
  Uint8List message,
  Uint8List? signature,
) async =>
    signature != null &&
    await _ed25519.verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );

bool _isWellFormed(Map<String, Object?> record) {
  final required = _requiredKeys[record['k']];
  if (required == null ||
      record.length != required.length ||
      !record.keys.every(required.contains)) {
    return false;
  }
  for (final MapEntry(:key, :value) in record.entries) {
    final ok = key == 'k' || key == 'sig' ? value is String : value is int;
    if (!ok) return false;
  }
  return (record['sig']! as String).length == 88;
}
