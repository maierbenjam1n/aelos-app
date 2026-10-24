# Handoff

_Last updated 2026-10-24: onboarding, mock pairing and instrument registration connected to the dashboard._

## State

- Protocol v1.0, Python reference verifier and shared test vectors are in `docs/ble-protocol.md`, `tools/` and `test/vectors/`.
- Three instruments have 30 days of signed seed history in `assets/seed/`; `domain/` contains models, chain verification, threshold evaluation and gap detection.
- `main.dart` now opens the collection dashboard. It loads the seed and starts a mock session for the Mittenwald violin; instrument cards open a detail screen with live readings, humidity charts for 24 h / 7 d / 30 d, gap marks and a signed event history.
- Long-press the Aelos mark for mock impact, free-fall, drying, disconnect/reconnect and reset controls. Live impact and fall alerts open the takeover screen; reconnects show a dismissible "While you were away" card.
- **Add an instrument** connects the illustrated onboarding, mock sensor pairing and certificate-style registration form. Profiles and optional photos are session-only; each registration gets its own test-only mock sensor key and starts a live session.
- The design system, seed loader, in-memory providers and signed mock sensor are implemented. The dashboard and detail screen use those existing providers.
- `fvm flutter analyze` is clean and `fvm flutter build web --dart-define=SENSOR=mock` succeeds.
- The onboarding permission gateway is still a fake demo implementation. Passport export/import and verification screens are not implemented.
- WebSocket and BLE transports are not implemented; `data/sensor_session.dart` currently throws for both. Android BLE and notification permissions remain to be added with BLE support.

## Next

1. Build passport export, import and verification, including the visible tamper-failure state.
2. Implement WebSocket and BLE transports and validate against the Pi.
3. Start the web portal after the phone demo is polished.

## Open issues with aelos-backend

- The backend repo was empty as of 2026-10-23. Share `docs/ble-protocol.md` and `test/vectors/` with the Pi developer; the protocol includes a `sync` control command.

## Demo machine

- FVM is at `~/fvm/bin` and the pinned Flutter SDK is 3.47.8. Android SDK is at `~/Android/Sdk`.
- Seed and mock signing keys are test-only and must not be used for real instruments.
