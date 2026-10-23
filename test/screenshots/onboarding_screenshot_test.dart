// Renders the onboarding pages to build/screens/ for design review.
// Run: fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true
import 'dart:io';

import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/features/onboarding/onboarding_screen.dart';
import 'package:aelos/features/onboarding/permission_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _frame = ValueKey('frame');

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
    ..addFont(
      file(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
  await Future.wait([serif.load(), sans.load(), icons.load()]);
}

// Time to let each page draw in and reach a frame that tells its story
// (for the impact page: the ripple on its way out, the trace mid-record).
const _pages = [
  ('climate', Duration(milliseconds: 3200)),
  ('impact', Duration(milliseconds: 2650)),
  ('provenance', Duration(milliseconds: 3000)),
  ('permissions', Duration(milliseconds: 1500)),
];

void main() {
  setUpAll(_loadFonts);

  for (final (name, theme) in [
    ('light', AelosTheme.light),
    ('dark', AelosTheme.dark),
  ]) {
    for (final (i, (page, settle)) in _pages.indexed) {
      testWidgets('onboarding $page $name', skip: !_enabled, (tester) async {
        tester.view
          ..physicalSize = const Size(1080, 2400)
          ..devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          RepaintBoundary(
            key: _frame,
            child: ProviderScope(
              overrides: [
                permissionGatewayProvider.overrideWithValue(
                  FakePermissionGateway(bluetooth: PermissionState.granted),
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: OnboardingScreen(initialPage: i, onFinished: () {}),
              ),
            ),
          ),
        );
        for (
          var t = Duration.zero;
          t < settle;
          t += const Duration(milliseconds: 50)
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        // Capture at device resolution (the default capture is in logical px).
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_frame),
        );
        await expectLater(
          boundary.toImage(pixelRatio: tester.view.devicePixelRatio),
          matchesGoldenFile(
            '../../build/screens/onboarding_${i + 1}_${page}_$name.png',
          ),
        );
        // Stop the looping illustrations before the test ends.
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
