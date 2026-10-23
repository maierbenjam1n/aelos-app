# domain/verification

Canonical JSON and hash-chain verification, exactly as `docs/ble-protocol.md` sections 5 and 7 describe.

- `canonicalBytes(record, includeSig:)`: the bytes that get signed (without `sig`) or hashed (with it).
- `ChainVerifier`: incremental, one `add(record)` per incoming record. `data/` keeps one per device. `prev` gives `prev_of_first` for exported bundles.
- `verifyChain(records, isolates:)`: whole list, reports the first failure in chain order. Pass `Platform.numberOfProcessors` for bundles. The web always uses one thread.

Speed: pure-Dart Ed25519 costs about 2 ms per signature on a desktop (AOT), and there's no shortcut, because every record's signature has to be checked (see the comment in `verifyChain`). A 7-day bundle (1,008 records) takes 2.0 s on 1 isolate and 0.32 s on 8. `cryptography_flutter` has no Android Ed25519, so it doesn't help here.

`test/domain/verification_test.dart` pins every case in `test/vectors/` on 1 and 3 isolates. If the vectors change, regenerate them with `tools/gen_test_vectors.py`; never edit them by hand.
