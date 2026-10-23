# Demo script (3 minutes)

_Draft. Fill in exact taps once the screens exist, and rehearse on both the mock and the Pi._

**Setup:** Android phone mirrored to the projector, dark mode, Do Not Disturb on (Aelos notifications allowed). Pi with sensor in the violin case, powered, about 2 m from the phone. App reset to seed state from the demo panel. Fallback build with `SENSOR=mock` installed and on the home screen.

| Time | On screen | Say | Action |
| --- | --- | --- | --- |
| 0:00 | Onboarding, first screen | "Fine instruments are worth more than most cars, yet nothing records how they're kept." | Swipe through onboarding. |
| 0:20 | Pairing: scanning animation, `Aelos-XXXX` found | "A small sensor lives in the case." | Tap the sensor and link it to "Violin, Mittenwald 1890". |
| 0:40 | Dashboard: instrument cards, live numbers counting up | "Climate at a glance: calm." | Open the violin. |
| 0:55 | Detail: live reading, 7-day chart with the 40–60 % band, a gap, "Tighter limits applied" note | "Its age and repair history tighten the limits." | Scroll the timeline briefly. |
| 1:20 | Impact alert takeover | "Someone knocks the case." | Tap the case firmly (fallback: demo panel → Impact). |
| 1:40 | Disconnect → reconnect → "While you were away" card | "Out of range for a while? It catches up." | Demo panel → Disconnect, tap the case again, Reconnect. |
| 2:00 | Passport PDF, share sheet | "A condition history you can hand to a buyer or insurer." | Export the last 7 days. |
| 2:20 | Verify: seal stamps | "Every record is signed by the sensor." | Import the bundle you just exported. |
| 2:35 | Verify, tampered: seal cracks, record highlighted | "Change one humidity value, and the seal breaks exactly there." | Import the pre-made tampered bundle. |
| 2:50 | Dashboard | Close: one sentence on who it's for. | |

## Fallback

If BLE fails at any point: long-press the logo → demo panel → transport **mock** → continue from the same step. The mock signs with the test key, so verification behaves identically. Never troubleshoot on stage.
