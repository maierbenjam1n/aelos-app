// Renders the style guide to build/screens/ for design review.
// Run: fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true
import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/core/theme/tokens.dart';
import 'package:aelos/core/widgets/f_hole.dart';
import 'package:aelos/features/style_guide/style_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  setUpAll(loadAppFonts);

  for (final (name, theme) in [('light', AelosTheme.light), ('dark', AelosTheme.dark)]) {
    testWidgets('style guide $name', skip: !_enabled, (tester) async {
      tester.view
        ..physicalSize = const Size(1080, 3400)
        ..devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const StyleGuideScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(StyleGuideScreen),
        matchesGoldenFile('../../build/screens/style_guide_$name.png'),
      );
    });
  }

  testWidgets('f-hole', skip: !_enabled, (tester) async {
    tester.view
      ..physicalSize = const Size(600, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ColoredBox(
        color: AelosPalette.ivory,
        child: Center(child: FHole(height: 800, color: AelosPalette.walnut)),
      ),
    );
    await expectLater(find.byType(FHole), matchesGoldenFile('../../build/screens/f_hole.png'));
  });
}
