# domain/history

Helpers for drawing a reading series.

- `findReadingGaps(records)`: stretches with no `r` record for more than 3× the typical interval (the median spacing). Charts hatch these. `findGaps(times)` does the same for plain timestamps.
- `downsampleReadings(records, bucket)`: min/max/mean per time bucket, in tenths, so a 30-day chart draws a few hundred points instead of 4,320. Empty buckets are left out.

Sequence gaps (missing `s` numbers) are a verification result, not this; see `domain/verification`.
