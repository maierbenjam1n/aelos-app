# data/seed

`SeedLoader().load()` reads `assets/seed/` and returns a `Seed`: six instruments (`Instrument`) with signed records (`SensorRecord`, raw lines kept): the original three with 30 days each, and three more Atelier Brunner rentals with 14 days each. Pass an `AssetBundle` to the constructor in tests. Loading and parsing all ~19k records (2.7 MB) takes well under a second; it doesn't verify signatures (see below).

The files come from `python3 tools/gen_seed.py`, which signs everything offline and is deterministic. Never edit them by hand: any change breaks the signatures. Change the generator and re-run it.

| Instrument | Sensor | Story in the data |
| --- | --- | --- |
| `violin-mittenwald` (1890, tighter limits) | `1AFB`, the **test key** | 7.5 h gap with a boot record 12 days before the end, 3.4 g impact 9 days before, a drying episode down to ~36 % RH 4 days before |
| `cello-mirecourt` (c. 1860, crack repair) | `076C` | 6.8 g impact 17 days before the end |
| `viola-cremona` (2014) | `3B54` | 230 ms free fall followed by a 4.7 g impact 6 days before the end |
| `violin-markneukirchen` (¾, c. 1925, tighter limits) | `20DF` | 14 days; 3.6 g knock (attention) 3 days before the end. Student rental |
| `cello-brunner` (2019) | `2A87` | 14 days; heating since the evening before the end: humidity falls to ~37.6 % and stays there, so it ends on "Needs attention" |
| `violin-mirecourt` (c. 1900, tighter limits) | `9A3C` | 14 days; steady workshop climate, 3.4 h gap with a boot while on the bench 5 days before the end. In the workshop, not rented |

Rentals (who has which instrument) are in `DemoDirectory.rentals` in `lib/data/accounts.dart`. Existing chains stay byte-identical when instruments are added: each profile carries its own `days` and random seed.

All keys are public and TEST ONLY. Because the violin uses the test key, the mock sensor can continue its chain live: the next record is `s = lastSeq + 1` and `prev` is the SHA-256 of the last record's full form.

**Time:** the seed ends at `Seed.endTime` (2026-10-24T08:00Z). `ts` is signed, so don't rewrite it; shift only what's displayed, by `DateTime.now().difference(seed.endTime)`.

**Verification:** each chain verifies (`test/data/seed_loader_test.dart`). Checking 4,300 signatures takes several seconds on a phone, so verify on startup only in an isolate, or trust the seed and verify incrementally from the last record (`ChainVerifier` with `prevOfFirst` set to its hash).
