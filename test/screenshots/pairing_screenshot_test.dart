// Renders the pairing states to build/screens/ for design review.
// Run: fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true
import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/features/pairing/pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_sensor_connection.dart';
import '../support/fonts.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  setUpAll(loadAppFonts);

  for (final (name, theme) in [('light', AelosTheme.light), ('dark', AelosTheme.dark)]) {
    testWidgets('pairing $name', skip: !_enabled, (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      Future<void> shot(String state) async {
        // Let state changes from the last timers render before capturing.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await expectLater(
          find.byType(PairingScreen),
          matchesGoldenFile('../../build/screens/pairing_${state}_$name.png'),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: PairingScreen(connection: FakeSensorConnection(), onPaired: (_) {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await shot('scanning');

      await tester.pump(const Duration(seconds: 2));
      await shot('found');

      await tester.tap(find.text('Aelos-1AFB'));
      await tester.pump(const Duration(milliseconds: 500));
      await shot('connecting');

      await tester.pump(const Duration(seconds: 2));
      await shot('linked');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
