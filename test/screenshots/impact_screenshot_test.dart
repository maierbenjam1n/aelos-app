// Renders the impact takeover to build/screens/ for design review.
// Run: fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true
import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/domain/models/condition_status.dart';
import 'package:aelos/domain/thresholds/alert.dart';
import 'package:aelos/domain/thresholds/threshold_config.dart';
import 'package:aelos/features/impact/impact_takeover_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

final _impact = Alert(
  instrumentId: 'violin-mittenwald',
  rule: ThresholdRule.impact,
  severity: ConditionStatus.actNow,
  time: DateTime.utc(2026, 10, 24, 12, 32, 7),
  seqs: const [4290],
  measured: 72,
  limit: 60,
  title: 'Strong impact recorded',
  why: 'The sensor recorded a 7.2 g impact.',
  whatToDo: 'Open the case and look for new cracks, a moved soundpost or a shifted bridge before playing.',
);

void main() {
  setUpAll(loadAppFonts);

  for (final (name, theme) in [('light', AelosTheme.light), ('dark', AelosTheme.dark)]) {
    testWidgets('impact takeover $name', skip: !_enabled, (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: ImpactTakeoverScreen(
            alert: _impact,
            instrumentName: 'Violin, Mittenwald 1890',
            displayTime: DateTime(2026, 10, 24, 14, 32, 7),
            onViewInstrument: () {},
            onDismiss: () {},
          ),
        ),
      );
      // Step in frames: an animation that starts during one long pump would
      // only get its first tick.
      for (final (label, ms) in [('ripple', 450), ('settled', 2500)]) {
        for (var t = 0; t < ms; t += 50) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await expectLater(
          find.byType(ImpactTakeoverScreen),
          matchesGoldenFile('../../build/screens/impact_${label}_$name.png'),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
