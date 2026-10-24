// Renders the luthier's screens to build/screens/ for design review.
// Run: fvm flutter test test/screenshots/luthier_screenshot_test.dart --update-goldens --dart-define=SCREENSHOTS=true
import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/data/accounts.dart';
import 'package:aelos/data/instruments_notifier.dart';
import 'package:aelos/data/sensor_session.dart';
import 'package:aelos/domain/models/account.dart';
import 'package:aelos/domain/models/event_report.dart';
import 'package:aelos/domain/models/live_reading.dart';
import 'package:aelos/features/luthier/fleet_instrument_screen.dart';
import 'package:aelos/features/luthier/luthier_home_screen.dart';
import 'package:aelos/features/luthier/report_review_screen.dart';
import 'package:aelos/sensor/sensor_connection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _frame = ValueKey('frame');
const _phone = Size(1080, 2400);
const _small = Size(945, 1680); // 360 × 640 dp

/// The cello's mock sensor, streaming, without timers.
class _LiveSession extends SessionNotifier {
  @override
  SessionState? build() => SessionState(
        instrumentId: 'cello-mirecourt',
        status: ConnectionStatus.connected,
        live: LiveReading(tenthsCelsius: 207, tenthsHumidity: 484, time: DateTime.now().toUtc()),
        lastSync: DateTime.now(),
      );
}

/// Two more reports so the inbox shows every state (review only; the demo
/// gets new ones from the renter's flow).
void _addReports(ProviderContainer c) {
  final reports = c.read(eventReportsProvider.notifier);
  reports.submit(
    EventReport(
      id: 'shot-cello-impact',
      instrumentId: 'cello-mirecourt',
      eventSeq: 1929,
      eventTitle: 'Strong impact recorded · 6.8 g',
      eventTime: DateTime.utc(2026, 10, 7, 17, 8, 51),
      explanation: 'The case caught the door frame on the way into the hall. '
          'I opened it straight away; nothing looked out of place.',
      causes: const ['Knocked while carrying'],
      photos: [
        for (final a in [PhotoAngle.front, PhotoAngle.back, PhotoAngle.bassSide, PhotoAngle.scroll])
          ReportPhoto(angle: a, takenAt: DateTime.utc(2026, 10, 7, 17, 40), assetPath: 'assets/photos/cello.jpg'),
      ],
      authorId: 'noah-keller',
      authorName: 'Noah Keller',
      createdAt: DateTime.utc(2026, 10, 7, 17, 46),
      luthierId: DemoDirectory.brunner.id,
    ),
  );
  reports.updateStatus('shot-cello-impact', ReportStatus.resolved,
      note: 'Checked on the bench: soundpost and seams fine.');
  // Sofia's report on the ¾ violin is part of the seeded inbox.
}

typedef _Act = Future<void> Function(WidgetTester tester);

Future<void> _settle(WidgetTester tester, [int ms = 1400]) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await tester.pump();
}

Future<void> _drag(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(Scrollable).last, Offset(0, -dy));
  await _settle(tester, 600);
  await _precache(tester);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await _settle(tester, 300);
  await tester.tap(target);
  await _settle(tester, 900);
  await _precache(tester);
}

void main() {
  setUpAll(loadAppFonts);

  final scenes = <(String, Widget, _Act?, Size)>[
    ('overview', const LuthierHomeScreen(), null, _phone),
    ('overview_scrolled', const LuthierHomeScreen(), (t) => _drag(t, 1050), _phone),
    ('fleet', const LuthierHomeScreen(initialTab: LuthierTab.fleet), null, _phone),
    ('alerts', const LuthierHomeScreen(initialTab: LuthierTab.alerts), null, _phone),
    ('reports', const LuthierHomeScreen(initialTab: LuthierTab.reports), null, _phone),
    ('account', const LuthierHomeScreen(), (t) async {
      await t.tap(find.byTooltip('Account'));
      await _settle(t, 900);
    }, _phone),
    ('review', const ReportReviewScreen(reportId: 'report-violin-knock'), null, _phone),
    ('review_photos', const ReportReviewScreen(reportId: 'report-violin-knock'), (t) => _drag(t, 900), _phone),
    ('review_inspection', const ReportReviewScreen(reportId: 'report-viola-fall'),
        (t) => _tap(t, 'Schedule inspection'), _phone),
    ('review_resolved', const ReportReviewScreen(reportId: 'shot-cello-impact'), (t) => _drag(t, 2000), _phone),
    ('instrument', const FleetInstrumentScreen(instrumentId: 'cello-brunner'), null, _phone),
    ('instrument_rental', const FleetInstrumentScreen(instrumentId: 'cello-brunner'), (t) => _drag(t, 700), _phone),
    ('instrument_return', const FleetInstrumentScreen(instrumentId: 'cello-brunner'),
        (t) => _tap(t, 'Return to workshop'), _phone),
    ('instrument_workshop', const FleetInstrumentScreen(instrumentId: 'violin-mirecourt'), (t) => _drag(t, 700), _phone),
    ('instrument_assign', const FleetInstrumentScreen(instrumentId: 'violin-mirecourt'), (t) async {
      await _tap(t, 'Assign to renter');
      await _tap(t, 'Anna Roth');
    }, _phone),
    ('small_overview', const LuthierHomeScreen(), null, _small),
    ('small_overview_scrolled', const LuthierHomeScreen(), (t) => _drag(t, 600), _small),
    ('small_alerts', const LuthierHomeScreen(initialTab: LuthierTab.alerts), null, _small),
    ('small_review', const ReportReviewScreen(reportId: 'report-viola-fall'), null, _small),
    ('small_instrument', const FleetInstrumentScreen(instrumentId: 'violin-markneukirchen'),
        (t) => _drag(t, 500), _small),
  ];

  for (final (theme, data) in [('light', AelosTheme.light), ('dark', AelosTheme.dark)]) {
    for (final (name, home, act, size) in scenes) {
      testWidgets('luthier $name $theme', skip: !_enabled, (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [sessionProvider.overrideWith(_LiveSession.new)],
        );
        addTearDown(container.dispose);
        await tester.runAsync(() => container.read(instrumentsProvider.future));
        container.read(accountProvider.notifier).signIn(AccountRole.luthier);
        _addReports(container);

        await tester.pumpWidget(
          RepaintBoundary(
            key: _frame,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(debugShowCheckedModeBanner: false, theme: data, home: home),
            ),
          ),
        );
        await tester.pump();
        await _precache(tester);
        await _settle(tester);
        if (act != null) await act(tester);
        await _settle(tester, 600);

        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
        await expectLater(
          boundary.toImage(pixelRatio: tester.view.devicePixelRatio),
          matchesGoldenFile('../../build/screens/luthier_${name}_$theme.png'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }
}
