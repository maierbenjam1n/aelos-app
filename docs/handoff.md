# Handoff

_Last updated 2026-10-24: the complete per-instrument audit log and pitch deck are ready._

## State

- Protocol v1.0, Python reference verifier and shared test vectors are in `docs/ble-protocol.md`, `tools/` and `test/vectors/`.
- Three instruments have 30 days of signed seed history in `assets/seed/`; `domain/` contains models, chain verification, threshold evaluation and gap detection.
- `main.dart` now opens the collection dashboard. It loads the seed and starts a mock session for the Mittenwald violin; instrument cards open a detail screen with live readings, humidity charts for 24 h / 7 d / 30 d, gap marks and a signed event history.
- Long-press the Aelos mark for mock impact, free-fall, drying, disconnect/reconnect and reset controls. Live impact and fall alerts open the takeover screen; reconnects show a dismissible "While you were away" card.
- **Add an instrument** connects the illustrated onboarding, mock sensor pairing and certificate-style registration form. Profiles and optional photos are session-only; each registration gets its own test-only mock sensor key and starts a live session.
- Instrument details share a designed PDF and `.aelos` ZIP bundle (7 days by default, with 30-day and full-history ranges). The dashboard imports bundles and checks record shape, sequence, signatures and chain; it distinguishes valid histories with reading gaps and highlights the first tampered record.
- Instrument details open a complete audit ledger with All / Climate / Events / Integrity filters, search, expandable signed JSON/signature/hash details, threshold rationale and a manual whole-chain signature check. Live records rejected by incremental verification are retained as deduplicated session-only incidents outside the signed history and shown in the ledger.
- The design system, seed loader, in-memory providers and signed mock sensor are implemented. The dashboard and detail screen use those existing providers.
- A 13-slide German pitch deck is available in `presentation/` as an interactive browser presentation and a static PDF; internal competitor notes are kept in `docs/presentation-business.md`.
- `fvm flutter analyze` is clean and `fvm flutter build web --dart-define=SENSOR=mock` succeeds.
- The onboarding permission gateway is still a fake demo implementation. Passport profile and range metadata are owner-supplied and are not sensor-signed.
- WebSocket and BLE transports are not implemented; `data/sensor_session.dart` currently throws for both. Android BLE and notification permissions remain to be added with BLE support.
- Audit, registration and passport changes have not been covered by a new test run.

## In progress

- `feat/login` (agent): designed sign-in/role screen, renter touches on the dashboard (managed by the luthier, contact), sign-out.
- `feat/event-report` (agent): guided event documentation (explanation, photo per angle with silhouette guide, review, submit).
- `feat/luthier` (agent): luthier fleet dashboard, renters and assignment, fleet alerts, reports inbox and review, extra seeded rental instruments.

## Next

1. Implement WebSocket and BLE transports and validate against the Pi.
2. Start the web portal after the phone demo is polished.

## Open issues with aelos-backend

- The backend repo was empty as of 2026-10-23. Share `docs/ble-protocol.md` and `test/vectors/` with the Pi developer; the protocol includes a `sync` control command.

## Demo machine

- **Android build:** `fvm flutter build apk --debug` works (first build ~16 min). Gradle needs NDK 28.2; the deprecated `sdkmanager` shim hangs when Gradle calls it, so install SDK packages yourself: `~/Android/Sdk/cmdline-tools/latest/bin/android --no-metrics sdk install "ndk;28.2.13676358" < /dev/null`.
- FVM is at `~/fvm/bin` and the pinned Flutter SDK is 3.47.8. Android SDK is at `~/Android/Sdk`.
- Seed and mock signing keys are test-only and must not be used for real instruments.
