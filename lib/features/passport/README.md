# Condition passport

From an instrument's detail screen, share a designed PDF certificate and a
`.aelos` ZIP bundle containing `manifest.json`, `records.jsonl`, and an
optional instrument photo. The default range is seven days; 30-day and full
history ranges are available. The bundle retains the previous-record hash so
partial histories can be verified against their original chain.

The dashboard's verification action imports `.aelos` bundles and checks every
record's shape, sequence, Ed25519 signature and hash chain. It reports valid
history, valid history with inferred reading gaps, or the first failing record.
Verification is read-only; it does not add the imported instrument to the
collection. Sensor records are signed; the instrument profile and date range
in the manifest are owner-supplied metadata.
