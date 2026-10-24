# data

In-memory state for the app, as Riverpod providers. There is no persistence; the seed loads on every start.

- `instrumentsProvider` (`InstrumentsNotifier`): the instruments as `InstrumentData` (signed history, alerts, status, tighter-limits note), loaded from `seed/` and evaluated by the threshold engine. `instrumentProvider(id)` selects one. `append(id, records)` adds verified records and returns the alerts they raised; `register(instrument)` adds a new in-memory profile.
- `sessionProvider` (`SessionNotifier`): one live sensor. `start(instrumentId, alreadyConnected:)` runs the protocol's connection sequence and runs it again after every reconnect. It verifies each record against the stored chain before keeping it, and appends records in real time. Records replayed after a reconnect are batched into `awaySummaryProvider` instead. `SessionState` carries status, the latest `LiveReading`, last sync time and any error. `mock` exposes the demo controls.
- `alertEventsProvider`: alerts from live records only, for the impact takeover and notifications.
- `transportProvider` and `sensorConnectionProvider`: mock, ws or ble (ws/ble arrive in step 4).

New registrations and their optional photo bytes remain in memory and are cleared when the app restarts.

**Time:** seeded and mock records are signed on the seed's timeline, which ends at `seed.endTime`. `InstrumentData.displayTime()` shifts them so the history ends at app start, and the mock signs with the same shift so live records continue it. Always format times through `displayTime`, never `record.time` directly. `sensorNow` is "now" on the signed timeline.
