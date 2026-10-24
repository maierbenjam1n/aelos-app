# features/luthier

The luthier's side of Aelos: Atelier Brunner's rental fleet, renters, fleet alerts and the event reports renters send.

- `LuthierHomeScreen`: top bar (long-press the Aelos mark for the demo panel; the monogram opens the account sheet with theme switch and sign out) and four tabs: **Overview** (workshop header, summary figures, "Needs your attention", the fleet), **Fleet** (rented out / in the workshop), **Alerts** (every alert across the fleet by day, filterable by severity), **Reports** (unreviewed first).
- `FleetInstrumentScreen`: condition at a glance, the rental panel (`rental_panel.dart`: assign or return via `rentalsProvider`), the instrument's alerts and reports. The full climate record is the shared `InstrumentDetailScreen` from `features/dashboard/`.
- `ReportReviewScreen`: the event, the matching signed record, the renter's words, the guided photos per `PhotoAngle`, and the actions Mark reviewed · Schedule inspection (with an optional note) · Resolve (`eventReportsProvider.updateStatus`).
- `luthier_fleet.dart`: derived providers (`fleetProvider`, `fleetAlertsProvider`, `fleetReportsProvider`, `attentionProvider`, `liveFleetIdProvider`). Severity order is the `ConditionStatus` index.
- `demo_renters.dart`: the workshop's demo address book (notes, email, phone) behind the assign sheet.
- Times: signed times go through `InstrumentData.displayTime`; report times use `FleetReport.display`, which shifts seeded (seed-timeline) reports the same way and leaves reports sent in this session alone.
- Review visuals with `test/screenshots/luthier_screenshot_test.dart` (adds two review-only reports so every inbox state shows).
