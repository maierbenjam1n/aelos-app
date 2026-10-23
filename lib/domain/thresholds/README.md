# domain/thresholds

Turns records into alerts, following `prompt.md` section 8. Rules live in `assets/config/thresholds.json` (every value a placeholder until a luthier validates it); `data/` loads the string and calls `ThresholdConfig.parse`.

- `ThresholdEngine(config:, instrumentId:, profile:)`: `evaluate(records, state)` returns `ThresholdResult(alerts, state)`. Keep the returned `ThresholdState` per instrument and pass it to the next call; the engine itself holds nothing. Signatures are not checked here.
- Rates use the records' timestamps (largest change within each window via sliding min/max), so 10-minute history and 2-second live data behave the same.
- Band and rate rules alert once per **episode**: when a violation starts (bands also when crossing sides or escalating to critical). An episode ends after 30 min back within limits. For rates, the 1 h and 24 h windows are one rule; a change measured from a reading that was already part of a reported excursion never alerts again, so a recovery or a 24 h window still spanning a past low stays quiet, while a fresh drop after a calm stretch alerts. 30 min between alerts of one rule is a hard cap. Impacts and drops always alert.
- `ThresholdProfile(yearMade:, hasCrackRepairs:)`: `engine.tighterLimits` / `engine.tighterLimitsReason` drive the note on the detail screen; humidity-rate limits are ×0.7 then.
- `Alert`: `title`, `why`, `whatToDo` for the feed; `id` / `notificationId` are per instrument + rule so repeats replace.
- `summarizeReplay(alerts)`: alerts from a reconnect batch become one `ReplaySummary` ("2 impacts and a dry spell while you were away").
- `currentStatus(...)`: worst of the latest reading's band severity and any rate/impact/drop alert in the last 6 h.
