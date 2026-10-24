# Passport bundle

`passport_bundle.dart` defines the `aelos/1` ZIP format. It contains a JSON
manifest, raw newline-delimited sensor records, and an optional photo. Partial
exports carry the hash of the record before the first included sequence so the
selected portion can still be checked against its original chain.

Verification authenticates sensor records with the sensor public key. The
manifest's instrument profile and date range are not signed by the sensor.
