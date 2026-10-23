# data/seed

`SeedLoader().load()` reads `assets/seed/` and returns a `Seed`: three instruments (`Instrument`) with 30 days of signed records each (`SensorRecord`, raw lines kept). Pass an `AssetBundle` to the constructor in tests. Loading and parsing all ~13k records takes well under a second; it doesn't verify signatures (see below).

The files come from `python3 tools/gen_seed.py`, which signs everything offline and is deterministic. Never edit them by hand: any change breaks the signatures. Change the generator and re-run it.

| Instrument | Sensor | Story in the data |
| --- | --- | --- |
| `violin-mittenwald` (1890, tighter limits) | `1AFB`, the **test key** | 7.5 h gap with a boot record 12 days before the end, 3.4 g impact 9 days before, a drying episode down to ~36 % RH 4 days before |
| `cello-mirecourt` (c. 1860, crack repair) | `076C` | 6.8 g impact 17 days before the end |
| `viola-cremona` (2014) | `3B54` | 230 ms free fall followed by a 4.7 g impact 6 days before the end |

All keys are public and TEST ONLY. Because the violin uses the test key, the mock sensor can continue its chain live: the next record is `s = lastSeq + 1` and `prev` is the SHA-256 of the last record's full form.

**Time:** the seed ends at `Seed.endTime` (2026-10-24T08:00Z). `ts` is signed, so don't rewrite it; shift only what's displayed, by `DateTime.now().difference(seed.endTime)`.

**Verification:** each chain verifies (`test/data/seed_loader_test.dart`). Checking 4,300 signatures takes several seconds on a phone, so verify on startup only in an isolate, or trust the seed and verify incrementally from the last record (`ChainVerifier` with `prevOfFirst` set to its hash).
