# features/onboarding

`OnboardingScreen(onFinished: …)`: three illustrated pages (climate, impacts, a provable history), then a permissions page; `onFinished` fires from its Continue button and hands over to pairing in `features/register/registration_flow.dart`. The intro is shown once per app session, before the first add-instrument flow.

- `onboarding_art.dart`: the three illustrations, one `CustomPainter` each (f-hole with breathing humidity contours, f-hole with an impact ripple and a recording trace, a guilloché seal that stamps in). They draw in when their page becomes active, then loop (6–8 s); with `MediaQuery.disableAnimations` they hold one still frame.
- `permissions_page.dart`: Bluetooth and notifications rows (to request / allowed / not allowed, with Allow or Retry). Continue never blocks, so a refused permission can't strand the demo.
- `permission_gateway.dart`: the `PermissionGateway` interface and `permissionGatewayProvider`, which currently returns `FakePermissionGateway` (grants after a short pause).

The platform gateway will implement the same interface without `permission_handler`. Bluetooth: `flutter_blue_plus` asks for `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` itself when a scan starts on Android 12+, so `requestBluetooth()` runs a brief scan and reports whether it was allowed. Notifications: `flutter_local_notifications` (`requestNotificationsPermission()` and `areNotificationsEnabled()` on Android, `requestPermissions()` on iOS). Override `permissionGatewayProvider` with it in `main.dart`; the manifest still needs the permissions (see `docs/handoff.md`).

Screenshots of every page in light and dark: `fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true` writes `build/screens/onboarding_*.png`.
