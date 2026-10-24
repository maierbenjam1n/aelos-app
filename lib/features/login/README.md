# features/login

The app's first screen, and the account menu every signed-in home shares. Demo accounts only (`data/accounts.dart`); there is no password and no typing on stage.

- `LoginScreen`: the Aelos mark, a serif line and three choice cards ("I own my instrument", "I rent from a luthier", "I am a luthier"), each with a `RoleMotif` that draws itself in. Choosing one cross-fades to a confirm step showing the demo account that will be used (name, role, the luthier, plan and "since" for a renter; workshop and fleet for a luthier) and a one-tap "Continue as …". It calls `accountProvider.notifier.signIn(role)`; `main.dart` routes to the role's home. Back (button or system) returns to the choice.
- `initialRole` opens straight on the confirm step, for screenshots.
- Short phones (under 720 dp tall) get a smaller mark and motif so both steps fit without scrolling at 360×640.
- `AccountButton` (`account_menu.dart`): the account's monogram for an app bar. Its sheet shows name and role, a dark-appearance switch, any extra `actions` (the dashboard adds the design-system preview), and "Sign out", which pops back to the root and returns to `LoginScreen`. The luthier home can use it too.
- `account_labels.dart`: role titles, the "Renter · Atelier Brunner, Luzern" line, and `formatDay` ("1 September 2026").
- Screenshots: `test/screenshots/login_screenshot_test.dart` (both steps, light and dark, 360×640, the renter dashboard and its sheets).
