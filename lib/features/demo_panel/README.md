# features/demo_panel

Backstage controls for the presenter, opened with `showDemoPanel` from a long-press on the Aelos mark.

- Events on the mock sensor: impact, free fall, drying trend on/off, disconnect/reconnect. They create real signed records, exactly as the Pi would.
- Transport switch (Wi-Fi and Bluetooth are disabled until build step 4).
- `resetDemoData(ref)` rebuilds everything from the seed and restarts the live session for `demoInstrumentId` (the Mittenwald violin, whose chain the mock continues). The app shell opens the panel from a long-press on the Aelos mark and provides the style-guide action.
