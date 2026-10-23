# sensor/mock

`MockSensorConnection` is an in-process sensor that follows `docs/ble-protocol.md` exactly: records are Ed25519-signed (TEST key by default) and hash-chained, nothing arrives on `records` before `sync(from)`, then every stored record with `s >= from` is replayed (20 ms apart, so `syncing` shows briefly) followed by new records. `live` sends every 2 s while connected.

- Climate: `MockEnvironment`, day/night 18–23 °C, humidity drifting within 45–52 %. Deterministic for a given `Random` and `now` clock.
- Readings every `readingInterval` (600 s like the Pi; use `demoReadingInterval`, 60 s, on stage).
- Demo commands: `impact` and `freefall` write real signed records at once (also while disconnected); `dry` lowers humidity 1.5 %/min to 30 %; `normal` ends it and humidity recovers at 3 %/min.
- `simulateDisconnect()` / `simulateReconnect()`: the sensor leaves and re-enters range. It keeps writing records meanwhile; the link comes back by itself if the app still wants it, and the app then sends `time` and `sync` as on any new connection.
- Chain continuity: pass `MockChainState.fromRecords(seededRecords)` (or `lastSeq` + `lastHash`) to continue a seeded history. `chainState` hands the current state to a new mock, e.g. after a transport switch.
- The sensor runs from construction; call `dispose()` (e.g. in `ref.onDispose`) to stop its timers and close its streams.
