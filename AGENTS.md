# Aelos app: agent guide

Aelos is a small sensor in the case of a fine string instrument. It measures temperature, humidity and impacts, and keeps a signed, hash-chained condition history. This repo holds the **Flutter phone app** (Android first), the **web portal** (phase two), the **protocol spec** and the tools around it. It's a **hackathon demo**: visual polish and on-stage reliability come before everything else. The full brief is in `prompt.md`; read sections 2, 6 and 12 before starting work.

## Repo boundaries

- `aelos-backend` (Raspberry Pi: sensors, signing, BLE peripheral, WebSocket server) belongs to a human developer. **Never modify it**: no commits, branches, PRs or issues. You may read it.
- `docs/ble-protocol.md` is the contract between the two repos. Changing it after publication: bump the version, add a changelog row, and flag the change in the PR description.
- When the Pi doesn't match the spec, record it under "Open issues with aelos-backend" in `docs/handoff.md` and work around it in the app.

## Run

```sh
fvm install                       # Flutter version pinned in .fvmrc
fvm flutter pub get
fvm flutter run --dart-define=SENSOR=mock                      # default, no hardware
fvm flutter run --dart-define=SENSOR=ws --dart-define=PI_HOST=192.168.1.42
fvm flutter run --dart-define=SENSOR=ble
fvm flutter analyze && fvm flutter test                        # must pass before a PR
python3 tools/gen_test_vectors.py                              # needs pynacl; output is deterministic
fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true  # renders screens to build/screens/ for review
```

## Where things live

| Path | What |
| --- | --- |
| `lib/main.dart`, `lib/main_portal.dart` | Phone app and web portal entry points |
| `lib/core/` | Design system (tokens, colours, type, motion), shared widgets, `AppConfig`. See `lib/core/README.md` |
| `lib/domain/` | Pure Dart (no Flutter): models, thresholds, verification, passport |
| `lib/sensor/` | `SensorConnection` and its `ble/`, `ws/`, `mock/` implementations |
| `lib/data/` | Seed loading and in-memory repositories |
| `lib/features/<name>/` | One folder per screen or flow, each with a short `README.md` |
| `assets/` | Fonts, seed JSON, photos, `config/thresholds.json` |
| `tools/` | Python: `aelos_chain.py` (reference signing and verification), vector and seed generators |
| `test/vectors/` | Protocol test vectors shared with the Pi developer. Don't edit by hand. |

## Docs

- `docs/architecture.md`: layers, providers, data flow
- `docs/ble-protocol.md`: the sensor contract
- `docs/decisions.md`: why things are the way they are. Add an entry for any significant choice.
- `docs/handoff.md`: current state. **Claim a task under "In progress" before you start, and update the file at the end of every session or PR.**
- `docs/demo-script.md`: the 3-minute demo

## Conventions

- Layers: `features → data → sensor → domain`. A layer imports only from layers below it. `core` may be used by `features` and `data`, never by `domain`.
- Riverpod 3 without code generation. No database, `go_router`, Rive, `printing`, `build_runner`, `freezed` or localisation tooling. Adding any package needs a `docs/decisions.md` entry.
- Keep protocol units (tenths of °C, % RH, g) inside `domain/` and `sensor/`. Convert only for display.
- Comments only where the *why* isn't obvious: protocol, crypto, workarounds, magic numbers. Public API in `domain/` and `sensor/` gets a one-line doc comment.
- Git: one branch per task (`feat/…`, `fix/…`), small PRs, imperative commit messages, never push directly to `main`. No AI co-author trailers or "generated with" footers.
