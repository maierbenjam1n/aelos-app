// Renders the event report flow to build/screens/ for design review.
// Run: fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true
import 'package:aelos/core/theme/aelos_colors.dart';
import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/data/accounts.dart';
import 'package:aelos/data/instrument_data.dart';
import 'package:aelos/data/instruments_notifier.dart';
import 'package:aelos/domain/models/account.dart';
import 'package:aelos/domain/models/condition_status.dart';
import 'package:aelos/domain/models/event_report.dart';
import 'package:aelos/domain/models/instrument.dart';
import 'package:aelos/domain/models/sensor_record.dart';
import 'package:aelos/domain/thresholds/alert.dart';
import 'package:aelos/domain/thresholds/threshold_config.dart';
import 'package:aelos/domain/thresholds/threshold_engine.dart';
import 'package:aelos/features/dashboard/instrument_detail_screen.dart';
import 'package:aelos/features/event_report/event_report_flow.dart';
import 'package:aelos/features/event_report/instrument_drawing.dart';
import 'package:aelos/features/event_report/report_detail_screen.dart';
import 'package:aelos/features/impact/fleet_banner.dart';
import 'package:aelos/features/impact/impact_takeover_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _frame = ValueKey('frame');
const _phone = Size(1080, 2400);
const _small = Size(945, 1680); // 360 × 640 dp

Instrument _instrument(String id, String name, InstrumentType type, String photo) => Instrument(
      id: id,
      name: name,
      type: type,
      yearMade: 1890,
      topWood: 'Spruce',
      backWood: 'Flamed maple',
      varnish: 'Oil varnish',
      sensorId: '1AFB',
      sensorPublicKey: '',
      photo: photo,
    );

final _violin = _instrument('violin-mittenwald', 'Violin, Mittenwald 1890', InstrumentType.violin, 'assets/photos/violin.jpg');
final _cello = _instrument('cello-mirecourt', 'Cello, Mirecourt', InstrumentType.cello, 'assets/photos/cello.jpg');

final _eventTime = DateTime.now().toUtc().subtract(const Duration(minutes: 7));

SensorRecord _record(int seq, Duration ago, RecordKind kind, {int? g, int? ms}) => SensorRecord(
      seq: seq,
      time: DateTime.now().toUtc().subtract(ago),
      kind: kind,
      signature: '',
      json: const {},
      raw: '',
      tenthsG: g,
      freeFallMs: ms,
    );

InstrumentData _data(Instrument i) => InstrumentData(
      instrument: i,
      records: [
        _record(4100, const Duration(days: 3), RecordKind.freeFall, ms: 180),
        for (var h = 0; h < 48; h++)
          SensorRecord(
            seq: 4200 + h,
            time: DateTime.now().toUtc().subtract(Duration(hours: 48 - h)),
            kind: RecordKind.reading,
            signature: '',
            json: const {},
            raw: '',
            tenthsCelsius: 205,
            tenthsHumidity: 480 + (h % 7) * 6,
          ),
        _record(4290, const Duration(minutes: 7), RecordKind.impact, g: 72),
      ],
      alerts: [
        Alert(
          instrumentId: i.id,
          rule: ThresholdRule.impact,
          severity: ConditionStatus.actNow,
          time: _eventTime,
          seqs: const [4290],
          measured: 72,
          limit: 60,
          title: 'Strong impact recorded',
          why: 'The sensor recorded a 7.2 g impact.',
          whatToDo: 'Open the case and check the bridge, soundpost and seams.',
        ),
      ],
      status: ConditionStatus.actNow,
      thresholdState: ThresholdState.initial(),
      displayOffset: Duration.zero,
    );

class _SignedIn extends AccountNotifier {
  _SignedIn(this.account);

  final Account account;

  @override
  Account? build() => account;
}

class _Reports extends EventReportsNotifier {
  _Reports(this.extra);

  final List<EventReport> extra;

  @override
  List<EventReport> build() => [...extra, ...super.build()];
}

ReportPhoto _asset(PhotoAngle angle, String path) =>
    ReportPhoto(angle: angle, takenAt: DateTime.now().toUtc(), assetPath: path);

final _photos = {
  PhotoAngle.front: _asset(PhotoAngle.front, 'assets/photos/violin.jpg'),
  PhotoAngle.back: _asset(PhotoAngle.back, 'assets/photos/viola.jpg'),
  PhotoAngle.bassSide: _asset(PhotoAngle.bassSide, 'assets/photos/cello.jpg'),
  PhotoAngle.scroll: _asset(PhotoAngle.scroll, 'assets/photos/violin.jpg'),
};

const _note = 'The case slipped off my shoulder on the stairs at the station and landed on its side. '
    'Nothing rattles, but the bridge looks slightly tilted.';

EventReport _submitted(Instrument i) => EventReport(
      id: 'report-shot',
      instrumentId: i.id,
      eventSeq: 4290,
      eventTitle: 'Strong impact recorded · 7.2 g',
      eventTime: _eventTime,
      explanation: _note,
      causes: const ['Case was dropped', 'During transport'],
      photos: [for (final p in _photos.values) p],
      authorId: DemoDirectory.renter.id,
      authorName: DemoDirectory.renter.name,
      createdAt: DateTime.now().toUtc(),
      luthierId: DemoDirectory.brunner.id,
      status: ReportStatus.reviewed,
      luthierNote: 'Thank you, Noah. Bring it by on Thursday afternoon; I’ll check the bridge and the soundpost.',
    );

Widget _flow(Instrument i, {int step = 0, Map<PhotoAngle, ReportPhoto> photos = const {}, bool notes = false}) =>
    EventReportFlow(
      instrumentId: i.id,
      eventTitle: 'Strong impact recorded · 7.2 g',
      eventTime: _eventTime,
      eventSeq: 4290,
      initialStep: step,
      initialPhotos: photos,
      initialCauses: notes ? const {'Case was dropped', 'During transport'} : const {},
      initialExplanation: notes ? _note : '',
    );

Future<void> _precache(WidgetTester tester) => tester.runAsync(() async {
      final context = tester.element(find.byKey(_frame));
      for (final path in {for (final p in _photos.values) p.assetPath!, 'assets/photos/viola.jpg'}) {
        for (final ImageProvider provider in [
          AssetImage(path),
          ResizeImage(AssetImage(path), width: 360),
          ResizeImage(AssetImage(path), width: 200),
        ]) {
          await precacheImage(provider, context);
        }
      }
    });

Future<void> _shoot(
  WidgetTester tester,
  String name,
  ThemeData theme,
  Widget home, {
  Size size = _phone,
  Account account = DemoDirectory.renter,
  List<EventReport> reports = const [],
  Duration settle = const Duration(milliseconds: 2400),
  Future<void> Function(WidgetTester tester)? act,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _frame,
      child: ProviderScope(
        overrides: [
          instrumentProvider.overrideWith((ref, id) => _data(id == _cello.id ? _cello : _violin)),
          accountProvider.overrideWith(() => _SignedIn(account)),
          eventReportsProvider.overrideWith(() => _Reports(reports)),
        ],
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: home),
      ),
    ),
  );
  await _precache(tester);
  if (act != null) await act(tester);
  for (var t = Duration.zero; t < settle; t += const Duration(milliseconds: 50)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
  await expectLater(
    boundary.toImage(pixelRatio: tester.view.devicePixelRatio),
    matchesGoldenFile('../../build/screens/event_report_$name.png'),
  );
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  setUpAll(loadAppFonts);

  for (final (mode, theme) in [('light', AelosTheme.light), ('dark', AelosTheme.dark)]) {
    testWidgets('drawings $mode', skip: !_enabled, (tester) async {
      tester.view
        ..physicalSize = const Size(2400, 1800)
        ..devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Builder(
            builder: (context) {
              final colors = AelosColors.of(context);
              return Scaffold(
                body: Column(
                  children: [
                    for (final type in [InstrumentType.violin, InstrumentType.cello, InstrumentType.doubleBass])
                      Expanded(
                        child: Row(
                          children: [
                            for (final angle in PhotoAngle.values)
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  color: colors.surface,
                                  child: CustomPaint(
                                    painter: InstrumentDrawingPainter(
                                      type: type,
                                      angle: angle,
                                      ink: colors.accent,
                                      detail: colors.textFaint,
                                    ),
                                    size: Size.infinite,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('../../build/screens/event_report_drawings_$mode.png'),
      );
    });

    testWidgets('explanation $mode', skip: !_enabled, (tester) async {
      await _shoot(tester, '1_explanation_$mode', theme, _flow(_violin, notes: true));
    });

    testWidgets('front violin $mode', skip: !_enabled, (tester) async {
      await _shoot(tester, '2_front_violin_$mode', theme, _flow(_violin, step: 1));
    });

    testWidgets('side cello $mode', skip: !_enabled, (tester) async {
      await _shoot(tester, '3_side_cello_$mode', theme, _flow(_cello, step: 3));
    });

    testWidgets('scroll violin $mode', skip: !_enabled, (tester) async {
      await _shoot(tester, '4_scroll_violin_$mode', theme, _flow(_violin, step: 5));
    });

    testWidgets('captured $mode', skip: !_enabled, (tester) async {
      await _shoot(tester, '5_captured_$mode', theme, _flow(_violin, step: 1, photos: _photos));
    });

    testWidgets('review $mode', skip: !_enabled, (tester) async {
      await _shoot(tester, '6_review_$mode', theme, _flow(_violin, step: 7, photos: _photos, notes: true));
    });

    testWidgets('review full $mode', skip: !_enabled, (tester) async {
      await _shoot(
        tester,
        '6_review_full_$mode',
        theme,
        _flow(_violin, step: 7, photos: _photos, notes: true),
        size: const Size(1080, 4400),
      );
    });

    testWidgets('report detail full $mode', skip: !_enabled, (tester) async {
      await _shoot(
        tester,
        '8_report_detail_full_$mode',
        theme,
        const ReportDetailScreen(reportId: 'report-shot'),
        reports: [_submitted(_violin)],
        size: const Size(1080, 5600),
      );
    });

    testWidgets('sent $mode', skip: !_enabled, (tester) async {
      await _shoot(
        tester,
        '7_sent_$mode',
        theme,
        _flow(_violin, step: 7, photos: _photos, notes: true),
        settle: const Duration(milliseconds: 2200),
        act: (tester) async {
          await tester.pump(const Duration(seconds: 1));
          await tester.tap(find.text('Send to Atelier Brunner'));
        },
      );
    });

    testWidgets('report detail $mode', skip: !_enabled, (tester) async {
      await _shoot(
        tester,
        '8_report_detail_$mode',
        theme,
        const ReportDetailScreen(reportId: 'report-shot'),
        reports: [_submitted(_violin)],
      );
    });

    testWidgets('history $mode', skip: !_enabled, (tester) async {
      await _shoot(
        tester,
        '9_history_$mode',
        theme,
        InstrumentDetailScreen(instrumentId: _violin.id),
        reports: [_submitted(_violin)],
        size: const Size(1080, 2400 * 3),
      );
    });

    testWidgets('takeover $mode', skip: !_enabled, (tester) async {
      final data = _data(_violin);
      await _shoot(
        tester,
        '10_takeover_small_$mode',
        theme,
        ImpactTakeoverScreen(
          alert: data.alerts.single,
          instrumentName: _violin.name,
          displayTime: _eventTime.toLocal(),
          onViewInstrument: () {},
          onDocument: () {},
          onDismiss: () {},
        ),
        size: _small,
        settle: const Duration(milliseconds: 3000),
      );
    });
  }

  testWidgets('fleet banner', skip: !_enabled, (tester) async {
    await _shoot(
      tester,
      'fleet_banner_dark',
      AelosTheme.dark,
      Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                FleetBanner(
                  eyebrow: 'Fleet alert · 09:53',
                  title: 'Cello, Mirecourt · 7.2 g',
                  detail: 'Noah Keller · Strong impact recorded',
                  severity: ConditionStatus.actNow,
                  icon: Icons.flash_on_rounded,
                  onOpen: () {},
                  onDismiss: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      size: _small,
    );
  });

  // Small phone checks: nothing may overflow at 360 × 640 dp.
  testWidgets('small explanation with keyboard', skip: !_enabled, (tester) async {
    await _shoot(
      tester,
      'small_explanation_keyboard',
      AelosTheme.light,
      _flow(_cello),
      size: _small,
      act: (tester) async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 280 * 2.625);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.showKeyboard(find.byType(TextField));
        await tester.enterText(find.byType(TextField), _note);
      },
    );
  });

  testWidgets('small photo step', skip: !_enabled, (tester) async {
    await _shoot(tester, 'small_detail_cello', AelosTheme.dark, _flow(_cello, step: 6), size: _small);
  });

  testWidgets('small review owner', skip: !_enabled, (tester) async {
    await _shoot(
      tester,
      'small_review_owner',
      AelosTheme.light,
      _flow(_violin, step: 7, photos: _photos),
      size: _small,
      account: DemoDirectory.owner,
    );
  });
}
