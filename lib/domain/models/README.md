# domain/models

Pure Dart value types shared by the phone app and the web portal.

- `SensorRecord`: one signed record. `SensorRecord.parse` takes a raw `records` payload (BLE body, or WebSocket message with `ch`). Values stay in protocol units (tenths) and are converted with getters.
- `LiveReading`: unsigned 2 s reading from `live`.
- `DeviceInfo`: contents of the `info` characteristic.
- `Instrument`: the register-instrument form (type, year or era, woods, varnish, crack repairs, photo) plus the paired sensor's ID and public key. `fromJson`/`toJson` match `assets/seed/instruments.json`. Age and repair rules read `yearMade` and `crackRepairs`; `era` is display only.

Keep `SensorRecord.json` exactly as received. Verification re-canonicalizes it, so normalizing or dropping fields here would break signatures.
