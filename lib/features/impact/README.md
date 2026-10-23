# features/impact

Hero moment 2: a knock or a fall, full screen, under a second after it happens.

- `AlertHost` wraps the app (`MaterialApp.builder`). It listens to `alertEventsProvider`: every live alert becomes a system notification (`core/notifications/`), and impacts and free falls also push `ImpactTakeoverScreen` on the given navigator. It also sends one notification for each new "While you were away" summary that contains alerts.
- `ImpactTakeoverScreen`: three rings ripple out from the centre, the peak g (or fall duration) counts up from zero, and it shows the severity badge, title, instrument and time (display time), and what to do. Actions: View instrument or Dismiss. Fires a heavy haptic on open.
- Replayed alerts never take over; they belong in the away card.

Screenshots: `test/screenshots/impact_screenshot_test.dart` (pumps frame by frame, because one long pump renders delayed animations at their first frame).
