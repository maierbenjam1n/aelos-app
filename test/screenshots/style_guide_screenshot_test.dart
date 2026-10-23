// Renders the style guide to build/screens/ for design review.
// Run: fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true
import 'dart:io';

import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/core/theme/tokens.dart';
import 'package:aelos/core/widgets/f_hole.dart';
import 'package:aelos/features/style_guide/style_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

Future<void> _loadFonts() async {
  Future<ByteData> file(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  final serif = FontLoader('CormorantGaramond');
  final sans = FontLoader('Inter');
  for (final f in Directory('assets/fonts').listSync().whereType<File>()) {
    if (!f.path.endsWith('.ttf')) continue;
    (f.path.contains('Cormorant') ? serif : sans).addFont(file(f.path));
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(file(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ));
  await Future.wait([serif.load(), sans.load(), icons.load()]);
}

void main() {
  setUpAll(_loadFonts);

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
