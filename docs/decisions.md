# Decisions

Newest first. Date, decision, why, alternatives rejected.

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
