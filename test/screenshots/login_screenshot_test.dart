// Renders the sign-in steps and the renter dashboard to build/screens/ for
// design review.
// Run: fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true
import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/data/accounts.dart';
import 'package:aelos/data/instruments_notifier.dart';
import 'package:aelos/domain/models/account.dart';
import 'package:aelos/features/dashboard/dashboard_screen.dart';
import 'package:aelos/features/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fonts.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _frame = ValueKey('frame');
const _phone = Size(1080, 2400);
const _small = Size(360 * 2.625, 640 * 2.625);

// Step in frames: an animation that starts during one long pump would only
// get its first tick.
Future<void> _settle(WidgetTester tester, Duration settle) async {
  for (var t = Duration.zero; t < settle; t += const Duration(milliseconds: 50)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _capture(
  WidgetTester tester,
  String name, {
  Duration settle = const Duration(milliseconds: 2400),
}) async {
  await _settle(tester, settle);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_frame));
  await expectLater(
    boundary.toImage(pixelRatio: tester.view.devicePixelRatio),
    matchesGoldenFile('../../build/screens/$name.png'),
  );
}

void _view(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

Widget _app(ThemeData theme, Widget home, {ProviderContainer? container}) {
  final app = MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: home);
  return RepaintBoundary(
    key: _frame,
    child: container == null
        ? ProviderScope(child: app)
        : UncontrolledProviderScope(container: container, child: app),
  );
}

void main() {
  setUpAll(loadAppFonts);

  for (final (name, theme) in [('light', AelosTheme.light), ('dark', AelosTheme.dark)]) {
    testWidgets('login choose $name', skip: !_enabled, (tester) async {
      _view(tester, _phone);
      await tester.pumpWidget(_app(theme, const LoginScreen()));
      await _capture(tester, 'login_1_choose_$name');
    });

    for (final role in AccountRole.values) {
      testWidgets('login confirm ${role.name} $name', skip: !_enabled, (tester) async {
        _view(tester, _phone);
        await tester.pumpWidget(_app(theme, LoginScreen(initialRole: role)));
        await _capture(tester, 'login_2_confirm_${role.name}_$name');
      });
    }

    testWidgets('renter dashboard $name', skip: !_enabled, (tester) async {
      _view(tester, _phone);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.runAsync(() => container.read(instrumentsProvider.future));
      container.read(accountProvider.notifier).signIn(AccountRole.renter);
      await tester.pumpWidget(_app(theme, const DashboardScreen(), container: container));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await _capture(tester, 'login_3_dashboard_renter_$name');
      await tester.tap(find.text('Contact your luthier'));
      await _capture(tester, 'login_7_contact_sheet_$name', settle: const Duration(milliseconds: 800));
      await tester.tap(find.text(DemoDirectory.brunner.email));
      await _capture(tester, 'login_8_contact_copied_$name', settle: const Duration(milliseconds: 500));
      await tester.tapAt(const Offset(200, 80));
      await _settle(tester, const Duration(milliseconds: 2500));
      await tester.tap(find.byTooltip('Account'));
      await _capture(tester, 'login_9_account_sheet_$name', settle: const Duration(milliseconds: 800));
      await tester.tapAt(const Offset(200, 80));
      await _settle(tester, const Duration(milliseconds: 600));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await _capture(tester, 'login_4_dashboard_renter_scrolled_$name', settle: const Duration(milliseconds: 600));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('login choose small', skip: !_enabled, (tester) async {
    _view(tester, _small);
    await tester.pumpWidget(_app(AelosTheme.light, const LoginScreen()));
    await _capture(tester, 'login_5_choose_small');
  });

  testWidgets('login confirm small', skip: !_enabled, (tester) async {
    _view(tester, _small);
    await tester.pumpWidget(_app(AelosTheme.light, const LoginScreen(initialRole: AccountRole.renter)));
    await _capture(tester, 'login_6_confirm_small');
  });
}
