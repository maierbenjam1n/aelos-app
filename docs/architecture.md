# Architecture

Feature-first Flutter app with four layers. Everything lives in memory. On startup the app loads pre-signed seed JSON, and sensor transports append to it.

```mermaid
flowchart TD
  subgraph features["features/ (screens, Riverpod providers)"]
    dash[dashboard / detail] --- alerts[alerts] --- pass[passport / verify] --- demo[demo_panel]
  end
  subgraph data["data/"]
    repo[InstrumentRepository<br/>RecordRepository]
    seed[seed loader]
  end
  subgraph sensor["sensor/"]
    iface[[SensorConnection]]
    ble[ble/] --> iface
    ws[ws/] --> iface
    mock[mock/] --> iface
  end
  subgraph domain["domain/ (pure Dart)"]
    models[models] --- thr[thresholds] --- ver[verification] --- pp[passport]
  end
  features --> data --> sensor --> domain
  data --> domain
  features --> domain
  seed -. assets/seed/*.json .-> repo
  core["core/ (theme, widgets, config)"] -.-> features
```

## Layers

| Layer | Responsibility | May import |
| --- | --- | --- |
| `domain/` | Value types, threshold engine, canonical JSON and chain verification, bundle format. No Flutter, so the portal and unit tests use it directly. | Dart SDK, `cryptography`, `archive` |
| `sensor/` | `SensorConnection` and its three transports. Turns bytes into domain models. | `domain` |
| `data/` | In-memory repositories per instrument: records, alerts, profile. Owns the active `SensorConnection`, runs the connection sequence, and feeds records through verification and thresholds. | `sensor`, `domain`, `core/config` |
| `features/` | Screens, widgets and the providers that adapt repositories to UI state. | everything below, `core` |
| `core/` | Design system (tokens, type, motion), shared widgets, `AppConfig`. | Flutter, `domain` |

## Sensor interface

`lib/sensor/sensor_connection.dart`. Screens never see which transport is active. `data/` drives the protocol connection sequence:

1. `connect(id)` returns `DeviceInfo`. On first pairing, store `publicKey`. Later, reject a mismatch.
2. `sendTime(now)`.
3. Listen to `records`, then `sync(lastSeq + 1)`.
4. Listen to `live`.

Records go through the chain verifier one by one (`prev` is kept per device) before they're stored. Replayed records feed the threshold engine in batch mode, and their alerts collapse into one "While you were away" summary.

Transport selection: `AppConfig.initialTransport` from `--dart-define=SENSOR`, switchable at runtime from the demo panel by replacing the `SensorConnection` provider.

## Providers (planned)

- `sensorConnectionProvider`: the active transport.
- `instrumentsProvider`: list for the dashboard.
- `instrumentProvider(id)`, `liveReadingProvider(id)`, `recordsProvider(id)`, `alertsProvider`.

Use plain `Provider`, `NotifierProvider` and `StreamProvider` (Riverpod 3, no codegen). Update this list when the providers exist.

## Verification

Verification runs in an isolate (`Isolate.run`) over a bundle's records, using the algorithm in `docs/ble-protocol.md` section 7. `test/vectors/` pins the expected results.
