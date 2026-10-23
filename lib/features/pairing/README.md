# features/pairing

Hero moment 1: find the sensor and link it.

- `PairingScreen(connection:, onPaired:)` works with any `SensorConnection` (mock, ws, ble). It calls `onPaired(DeviceInfo)` when the user taps Continue, and the caller stores the public key and moves on to registering the instrument.
- `PairingController` is a `ValueNotifier` state machine: `Scanning(found)` → `Connecting` → `Paired`, or `PairingFailed` with a retry. It keeps "Connecting" on screen for at least 0.9 s so it can be read, and doesn't wait for the scan to stop.
- `ScanningHalo`: the f-hole draws in while hairline rings drift outward; the rings stop once linked.
- The linked state shows the key fingerprint (`keyFingerprint`, first 8 bytes) as a quiet cue that the history is signed.

Screenshots: `test/screenshots/pairing_screenshot_test.dart`.
