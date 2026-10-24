# Demo script (3 minutes)

**Setup:** From the repository root run `fvm flutter run -d chrome --dart-define=SENSOR=mock`. The app opens on the seeded collection. Pairing, onboarding permissions, registrations and photos use in-memory demo data; they reset when the app restarts.

| Time | On screen | Say | Action |
| --- | --- | --- | --- |
| 0:00 | Collection dashboard | "A considered condition record for every instrument in your care." | Point out the seeded violin, cello and viola. |
| 0:15 | Onboarding, then pairing | "A small sensor lives in the case. It signs every record." | Tap **Add an instrument**. Continue through onboarding and permissions, then select the discovered mock sensor. |
| 0:45 | Instrument certificate | "We begin with what the owner knows about the instrument." | Enter a name and year, choose materials, optionally attach a photo, then add it to the collection. |
| 1:05 | Seeded violin detail | "The older profile has tighter climate limits, and its history shows where readings stopped." | Return to the collection, open the Mittenwald violin, and show the 30-day chart and recent timeline. |
| 1:20 | Full audit log | "Every reading and event can be traced to its signed record, and we can check the entire chain." | Tap the receipt icon → **Climate** → expand a reading → **Check chain**. |
| 1:40 | Impact alert takeover | "A knock becomes a signed event in the condition history." | Long-press the Aelos mark → **Impact**. |
| 1:55 | Reconnect summary | "When the phone comes back in range, it catches up on signed records." | Long-press the mark → **Disconnect**; trigger an impact while away; reopen the panel → **Reconnect**. |
| 2:15 | Passport share | "This history travels with the instrument." | Open the violin detail → share icon → choose **30 days** → share the PDF and `.aelos` bundle. |
| 2:35 | Verification seal | "The bundle checks each signature and the chain between records." | Return to the dashboard → shield icon → select the `.aelos` file. The seeded 30-day history should show **Verified with gaps**. |
| 2:55 | Collection | Close with who the app serves. | Return to the collection. |

## Tamper demonstration

Prepare a copy of a 30-day `.aelos` bundle before the presentation. Unzip it,
change one value in a line in `records.jsonl` without changing that record's
signature, then zip the files back with `manifest.json` and `records.jsonl` at
the archive root. Import the copy from the dashboard's shield action. The app
should name the first record whose signature no longer matches.

## Limits

The pairing sensor is simulated. The onboarding permission gateway is also a
demo placeholder; this flow does not request real Bluetooth or notification
permissions. WebSocket and BLE transports still need implementation and
validation against the Pi.
