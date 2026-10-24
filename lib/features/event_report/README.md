# features/event_report

Guided documentation of a signed event (an impact or a drop): what happened, one photo per angle, then review and submit.

- `EventReportFlow` (`EventReportFlow.route(instrumentId:, eventTitle:, eventTime:, eventSeq:)`): full-screen, 8 steps with a segmented hairline progress header. Explanation (quick answers + a ruled serif note) → one `PhotoStep` per `PhotoAngle` → `ReviewStep` → `ReportSent` seal, then it closes itself.
- Renters send to their luthier (`rentalsProvider` → `DemoDirectory`); owners add to their own history. Submits through `eventReportsProvider.notifier.submit`. `createdAt` and `takenAt` are on the signed timeline (`sensorNow`), like `eventTime`, so format them with `displayTime`.
- `InstrumentDrawingPainter`: hand-drawn line art per angle and family (violin/viola, cello with endpin and deep ribs, bass with sloped shoulders), drawn in by an animation. `AngleGuide` puts it in a viewfinder frame, or shows the captured photo.
- Photos: `photoSourceProvider` wraps `image_picker` (downscaled to 1600 px, quality 85, kept as bytes). Cancel stays put; refused permission shows a calm note. Override the provider to stub it.
- `ReportDetailScreen(reportId:, actionsBuilder:)` and `ReportView`: photos (swipe; tap for the full-screen `ReportPhotoGallery`), the event, status track, the author's words, destination. `actionsBuilder` adds a pinned footer, e.g. the luthier's status actions. `ReportHistoryCard` is the history entry.
- `ReportPhotoImage` shows `ReportPhoto.bytes` or `.assetPath`.

Screenshots: `test/screenshots/event_report_screenshot_test.dart`.
