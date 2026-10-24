# Dashboard

The mock-first home for the seeded instrument collection and its live sensor.

- `DashboardScreen` loads the in-memory collection and starts the mock session for the seeded violin.
- Instrument cards show the latest climate readings, condition, photo and recent humidity trend.
- Tapping a card opens `InstrumentDetailScreen` with a selectable humidity history and event timeline.
- **Add an instrument** opens onboarding (once per app session), mock sensor pairing and a certificate-style registration form. New profiles and optional photos are kept in memory.
- Long-press the Aelos mark for the mock demo panel; reconnect summaries appear on the dashboard.
- The design-system preview remains reachable from the palette action in the app bar.
