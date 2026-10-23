# Handoff

_Last updated 2026-10-23, end of build step 1._

## State

- **Protocol spec v1.0** (`docs/ble-protocol.md`) published with test vectors (`test/vectors/`) and a Python reference implementation (`tools/aelos_chain.py`). Ready to hand to the Pi developer.
- **Skeleton:** `pubspec.yaml`, lints, `.fvmrc`, `AppConfig`, domain models, `SensorConnection` interface, placeholder `main.dart`. **Never compiled**: Flutter wasn't installed on the machine that wrote it.
- **Docs:** `AGENTS.md` (+ `CLAUDE.md` symlink), architecture, decisions, demo script (draft).

## First thing to do on a machine with Flutter

```sh
fvm install
fvm flutter create --project-name aelos --org ch.aelos --platforms android,ios,web .
rm test/widget_test.dart          # generated, references a MyApp that doesn't exist
fvm flutter pub get && fvm flutter analyze
```

Then commit the generated `android/`, `ios/` and `web/` folders. Android needs Bluetooth and notification permissions in `AndroidManifest.xml` (see the `flutter_blue_plus` README).

## In progress

_Nothing claimed._

## Next (build step 2)

1. Design system in `lib/core/theme/`: tokens, type scale, motion durations. Bundle Cormorant Garamond and Inter into `assets/fonts/` and set `GoogleFonts.config.allowRuntimeFetching = false`.
2. `domain/verification/`: canonical JSON and chain verifier, with tests against every `test/vectors/*.json` file.
3. `tools/gen_seed.py` (reuse `aelos_chain.py`) and the seed loader in `data/seed/`.
4. Mock sensor in `sensor/mock/`.
5. Dashboard and instrument detail on the mock.

## Known bugs

None known (nothing runs yet).

## Open issues with aelos-backend

- `aelos-backend` is empty as of 2026-10-23. Send the Pi developer `docs/ble-protocol.md` and `test/vectors/`.
- The spec adds a `sync` control command that isn't in the original brief (see `docs/decisions.md`). Make sure the Pi developer knows about it.

## Repo notes

- `origin` is `github.com:maierbenjam1n/aelos-app`. The SSH key on the dev machine authenticates as a different account (`MaierBenjamin`), which has no push access yet. Branches `feat/ble-protocol` → `feat/skeleton` (stacked) are local only until that's fixed.
