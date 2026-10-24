# Aelos

Aelos is a small sensor that sits in the case of a fine string instrument. It records temperature, humidity, knocks and falls, and signs every reading into a hash-chained condition history. This history cannot be changed afterwards without detection. This repository holds the **Flutter phone app** (Android first) and the **sensor protocol**. It was built as a hackathon demo.

## What the app does

- **Three roles.** Sign in with one tap as an owner, a renter or a luthier. The demo accounts need no password.
- **Owners and renters** see their instruments' current climate, with humidity charts for 24 hours, 7 days and 30 days, plus a signed event history.
- **Live alerts.** A knock or fall opens a full-screen alert, and the owner or renter can document the event with a photo of each angle.
- **Luthiers** see their rental fleet, fleet alerts, incoming event reports and the renters' details.
- **Audit and passport.** Every record can be checked in an audit log. A history can be exported as a PDF or a `.aelos` bundle, and the app verifies imported bundles and highlights the first tampered record.

The app runs with a built-in **mock sensor** and 30 days of signed sample data, so no hardware is needed. The real sensor (a Raspberry Pi) lives in the separate `aelos-backend` repository, and the Wi-Fi and Bluetooth connections to it are not implemented yet.

## Getting started

You need [FVM](https://fvm.app). It installs the pinned Flutter version (3.47.8).

```sh
fvm install
fvm flutter pub get
fvm flutter run --dart-define=SENSOR=mock     # on a connected Android phone or emulator
fvm flutter run -d chrome                      # or in the browser
```

In the app, **long-press the Aelos mark** to open the demo panel. From there you can trigger an impact or a fall, start a drying trend, disconnect and reconnect the sensor, or reset the demo data.

To build an APK, run `fvm flutter build apk --debug`. The first build takes about 15 minutes and needs Android NDK 28.2; `docs/handoff.md` describes the setup.

Before opening a pull request, run `fvm flutter analyze && fvm flutter test`.

## Project layout

| Path | What |
| --- | --- |
| `lib/features/` | One folder per screen or flow |
| `lib/data/` | Sample data, demo accounts and the live sensor session |
| `lib/sensor/` | Sensor connection and the mock sensor |
| `lib/domain/` | Models, signature and chain verification, alert thresholds |
| `lib/core/` | Design system and shared widgets |
| `assets/` | Fonts, signed sample data, photos, threshold config |
| `tools/` | Python reference implementation of signing and verification |

## Further reading

- [docs/ble-protocol.md](docs/ble-protocol.md): the contract between the app and the sensor
- [docs/architecture.md](docs/architecture.md): layers and data flow
- [docs/decisions.md](docs/decisions.md): why things are built the way they are
- [docs/handoff.md](docs/handoff.md): current state and open issues
- [AGENTS.md](AGENTS.md): conventions for contributors
