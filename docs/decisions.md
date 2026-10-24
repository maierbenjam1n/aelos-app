# Decisions

Newest first. Date, decision, why, alternatives rejected.

### 2026-10-24: Passport signatures cover sensor records, not the manifest
The `.aelos` bundle carries the sensor's public key and chain context so every included record can be verified, including partial ranges. Instrument profile and range are owner-supplied metadata because the sensor has no signing API for them and the app has no account key. The PDF and verification screen state that boundary. Rejected: implying that the sensor cryptographically attests to maker, repairs, ownership, or export dates.

### 2026-10-24: Registration gets a separate test-only mock sensor identity
The seeded violin's mock connection already continues its signed history, so pairing another instrument to it would incorrectly give two instruments one key and chain. The registration flow creates a deterministic test-only mock key per new registration and hands that connection to the active session. Registration profile and photo bytes stay in memory, consistent with the demo's no-persistence scope. Rejected: reusing the seeded sensor (misrepresents ownership) and adding a database (outside the hackathon brief).

### 2026-10-24: Seed data signed offline, displayed with a time offset
`tools/gen_seed.py` signs 30 days of history per instrument (ending 2026-10-24T08:00Z) with fixed TEST keys, so every rehearsal is identical and startup does no signing. The violin's sensor uses the protocol TEST key so the mock can continue its chain (`test/sensor/mock_continues_seed_test.dart`). Signed timestamps can't change, so the UI shifts display times by `appStart - seed.endTime`, and the mock signs in that same shifted timeline. Seed chains are trusted at startup, not re-verified (about 8 s on 4 isolates). Photos are CC0 Met Museum images (`assets/photos/CREDITS.md`).

### 2026-10-24: Mock sensor behaves like the Pi, plus demo-only controls
`MockSensorConnection` follows the spec exactly (nothing before `sync`, paced replay, signed demo records). `simulateDisconnect()` and `simulateReconnect()` model going out of range: the sensor keeps recording, and `data/` must re-run `sendTime` + `sync(lastSeq + 1)` on reconnect. Demo commands work while disconnected (a real BLE write wouldn't) so "impact while you were away" can be staged. Added `fake_async` as a dev dependency for its timer tests. `dispose()` is on the mock only for now; add it to `SensorConnection` with the real transports.

### 2026-10-24: Threshold engine is pure and stateless; alerts per episode
`ThresholdEngine.evaluate(records, state)` returns alerts and a new state; `data/` keeps one state per instrument. Rates use the readings' timestamps, so 10-minute and 2-second data behave the same. Band and rate rules alert once per episode (when a violation starts or worsens), capped at one per rule per 30 minutes; impacts and free falls always alert. ×0.7 limits round to tenths (3.5 %/h, 7.0 %/24 h), and the age rule is "over 100 years" rather than a fixed year. Status = worst of the current band severity and rate/impact/fall alerts from the last 6 hours. All values in `assets/config/thresholds.json` are placeholders for a luthier to validate.

### 2026-10-24: Fonts bundled through pubspec, `google_fonts` dropped
Static latin-subset TTFs of Cormorant Garamond (400/500/600, italics) and Inter (300–600) from Fontsource, declared in `pubspec.yaml`, with OFL licences in `assets/fonts/`. Works offline with no runtime lookup, and keeps OpenType `tnum` for tabular readings. Rejected: `google_fonts` (with bundled assets it adds nothing but file-name conventions), variable fonts (weight-axis handling is inconsistent across Flutter platforms).

### 2026-10-24: Status colours split into mark, ink and tint
WCAG: text 4.5:1, icons/marks 3:1. The brief's amber `#D9A35B` is only 2:1 on ivory, so light mode uses `#A06B24` for the attention mark and `#8F5A1E` for its text; the brief's pure colours remain as 16 % tints behind badges, and are used directly in dark mode where they pass. `test/core/contrast_test.dart` enforces this. Distinct icon shapes (circle-check, triangle, octagon) so status reads without colour.

### 2026-10-24: Screenshots via golden tests into `build/screens/`
Agents review visuals by rendering widgets with the real fonts in `flutter test` (opt-in with `--dart-define=SCREENSHOTS=true`). Output is gitignored; these are review images, not regression goldens.

### 2026-10-24: Verify signatures in parallel isolates, pure Dart
Pure-Dart Ed25519 verify is about 2 ms per record on a desktop (both `cryptography`'s `DartEd25519` and `ed25519_edwards`; the latter is slower), so a 7-day bundle would take several seconds on a phone. `verifyChain` does the hash chain in one cheap sequential pass, then splits the signature checks across isolates: 0.32 s for 1,008 records on 8 isolates. Rejected: `cryptography_flutter` (Ed25519 is Apple-only, Android falls back to Dart); checking only the last signature (unsound: a record's hash excludes its own `prev`, so signatures don't vouch transitively); libsodium via FFI (native setup, no web).

### 2026-10-23: Explicit `sync` command for record replay
App writes `{"cmd":"sync","from":n}` after subscribing to `records`; the sensor sends nothing on `records` before that. BLE notifications are unacknowledged, so the sensor cannot know what was "undelivered"; the app knows exactly which sequence numbers it holds. Rejected: sensor-side delivery tracking (loses records on a dropped link), indications (slow, harder in `bless`). Adds `sync()` to `SensorConnection`.

### 2026-10-23: Device ID derived from the public key
`id` = first 2 bytes of SHA-256(pk), hex. Deterministic, needs no extra storage on the Pi, and lets the app sanity-check `info`. Collisions are irrelevant for a demo with one or two sensors. Rejected: MAC-based ID (varies by adapter, not available via `bless` cleanly).

### 2026-10-23: Minimum MTU 185, one JSON object per packet
A signed reading is 144 bytes (above the 130 estimate), so records cannot fit the default 23-byte MTU. Android and BlueZ both negotiate 247. Rejected: chunking/framing (complexity on both sides for no demo benefit).

### 2026-10-23: Demo triggers create real signed records
`impact` and `freefall` demo commands go through the normal signing path, so the live alert, the history and verification all show the same event. Rejected: unsigned "demo" events (would be missing from exported bundles).

### 2026-10-23: Flat WebSocket messages with a `ch` key
Matches the brief; body is the BLE body plus `ch`. `SensorRecord.parse` strips `ch` before verification. Rejected: nested `{"ch":…,"d":{…}}` (diverges from the brief the Pi developer has seen).

### 2026-10-23: Test key from a fixed string
Seed = SHA-256("aelos test key - TEST ONLY"), committed in `test/vectors/test_key.json`. Shared by vectors, mock sensor and seed data so all three verify identically.

### 2026-10-23: `flutter_lints` over `very_good_analysis`
`very_good_analysis` requires doc comments on every public member, which conflicts with the "no comments that restate the code" rule and slows a hackathon. `flutter_lints` plus a few strict rules in `analysis_options.yaml`.

### 2026-10-23: Current major versions (Riverpod 3, flutter_blue_plus 2)
Pinned Flutter 3.47.8 / Dart 3.13 and the latest package majors as of today. Riverpod 3: use `Notifier`/`StreamProvider`; `StateProvider` is legacy, don't use it.
