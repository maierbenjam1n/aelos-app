# Dashboard

The mock-first home for the seeded instrument collection and its live sensor.

- `DashboardScreen` is the home for owners and renters. It shows `visibleInstrumentsProvider` (the owner's collection, or the renter's rental); `main.dart` starts the live session for the role's instrument.
- Instrument cards show the latest climate readings, condition, photo and recent humidity trend.
- Tapping a card opens `InstrumentDetailScreen` with a selectable humidity history and event timeline.
- Renters see "Your rental", a **Managed by** card (workshop, plan, since, from `rentalsProvider` and `DemoDirectory`) and **Contact your luthier**, a sheet with phone and email that copy on tap. "Add an instrument" is hidden for renters: the luthier provides the equipment.
- **Add an instrument** (owners) opens onboarding (once per app session), mock sensor pairing and a certificate-style registration form. New profiles and optional photos are kept in memory.
- Long-press the Aelos mark for the mock demo panel; reconnect summaries appear on the dashboard.
- The monogram in the app bar (`AccountButton` from `features/login`) opens the account sheet: dark appearance, the design-system preview, and sign-out.
