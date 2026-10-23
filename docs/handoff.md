# Handoff

_Last updated 2026-10-24, end of build step 1._

## State

- **Protocol spec v1.0** (`docs/ble-protocol.md`) published with test vectors (`test/vectors/`) and a Python reference implementation (`tools/aelos_chain.py`). Ready to hand to the Pi developer.
- **Skeleton:** `pubspec.yaml`, lints, `.fvmrc`, `AppConfig`, domain models, `SensorConnection` interface, placeholder `main.dart`, platform folders (`android/`, `ios/`, `web/`; org `ch.aelos`). `flutter analyze` is clean, `flutter test` passes, and `flutter build web` works.
- **Docs:** `AGENTS.md` (+ `CLAUDE.md` symlink), architecture, decisions, demo script (draft).

## Dev machine

- fvm is in `~/fvm/bin` (not on `PATH` by default). The Flutter SDK is at `.fvm/flutter_sdk`.
- Android SDK command-line tools are in `~/Android/Sdk`. No Android build has been tried yet: the SDK licences have to be accepted by a human first (`fvm flutter doctor --android-licenses`).
- Android still needs Bluetooth and notification permissions in `AndroidManifest.xml` (see the `flutter_blue_plus` README). Add them with the BLE transport.

## In progress

_Nothing claimed._

## Next (build step 2)

1. Design system in `lib/core/theme/`: tokens, type scale, motion durations. Bundle Cormorant Garamond and Inter into `assets/fonts/` and set `GoogleFonts.config.allowRuntimeFetching = false`.
2. `domain/verification/`: canonical JSON and chain verifier, with tests against every `test/vectors/*.json` file.
3. `tools/gen_seed.py` (reuse `aelos_chain.py`) and the seed loader in `data/seed/`.
4. Mock sensor in `sensor/mock/`.
5. Dashboard and instrument detail on the mock.

## Known bugs

None known.

## Open issues with aelos-backend

- `aelos-backend` is empty as of 2026-10-23. Send the Pi developer `docs/ble-protocol.md` and `test/vectors/`.
- The spec adds a `sync` control command that isn't in the original brief (see `docs/decisions.md`). Make sure the Pi developer knows about it.

## Repo notes

- Branches awaiting PRs: `feat/ble-protocol` → `main`, then `feat/skeleton` (stacked on it). Merge in that order.
