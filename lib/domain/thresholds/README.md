# domain/thresholds

Turns records into alerts, following `prompt.md` section 8. Rules live in `assets/config/thresholds.json` (every value a placeholder until a luthier validates it); `data/` loads the string and calls `ThresholdConfig.parse`.

- `ThresholdEngine(config:, instrumentId:, profile:)`: `evaluate(records, state)` returns `ThresholdResult(alerts, state)`. Keep the returned `ThresholdState` per instrument and pass it to the next call; the engine itself holds nothing. Signatures are not checked here.
- Rates use the records' timestamps (largest change within each window via sliding min/max), so 10-minute history and 2-second live data behave the same.
- Band and rate rules fire at most once per rule per 30 min (escalation to critical always fires). A band fires when a violation starts, not on every reading of it. Impacts and drops are never debounced.
- `ThresholdProfile(yearMade:, hasCrackRepairs:)`: `engine.tighterLimits` / `engine.tighterLimitsReason` drive the note on the detail screen; humidity-rate limits are ×0.7 then.
- `Alert`: `title`, `why`, `whatToDo` for the feed; `id` / `notificationId` are per instrument + rule so repeats replace.
- `summarizeReplay(alerts)`: alerts from a reconnect batch become one `ReplaySummary` ("2 impacts and a dry spell while you were away").
- `currentStatus(...)`: worst of the latest reading's band severity and any rate/impact/drop alert in the last 6 h.
