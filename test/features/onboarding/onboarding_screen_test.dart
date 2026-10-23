import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/features/onboarding/onboarding_screen.dart';
import 'package:aelos/features/onboarding/permission_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakePermissionGateway gateway;
  late int finished;

  setUp(() {
    gateway = FakePermissionGateway(delay: const Duration(milliseconds: 200));
    finished = 0;
  });

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    bool still = false,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [permissionGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: AelosTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: still,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: OnboardingScreen(onFinished: () => finished++),
        ),
      ),
    );
  }

  // The illustrations loop forever, so pumpAndSettle would never return.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  testWidgets('walks through the story and permissions', (tester) async {
    await pumpOnboarding(tester);
    await settle(tester);
    expect(find.text('The climate\ninside the case'), findsOneWidget);
    expect(button('Continue'), findsOneWidget);

    await tester.tap(button('Continue'));
    await settle(tester);
    expect(find.text('Every knock,\nnoticed'), findsOneWidget);

    // Swipe to the third page: the button now reads "Get started".
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await settle(tester);
    expect(find.text('A history\nyou can prove'), findsOneWidget);
    expect(button('Get started'), findsOneWidget);
    expect(button('Continue'), findsNothing);

    await tester.tap(button('Get started'));
    await settle(tester);
    expect(find.text('Two small\npermissions'), findsOneWidget);
    expect(find.text('TO REQUEST'), findsNWidgets(2));

    await tester.tap(find.text('Allow').first);
    await settle(tester);
    expect(gateway.bluetooth, PermissionState.granted);
    expect(find.text('ALLOWED'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await settle(tester);
    expect(gateway.notifications, PermissionState.granted);
    expect(find.text('ALLOWED'), findsNWidgets(2));

    expect(finished, 0);
    await tester.tap(button('Continue'));
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('skip goes to permissions, and Continue never blocks', (
    tester,
  ) async {
    await pumpOnboarding(tester, still: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Two small\npermissions'), findsOneWidget);

    await tester.tap(button('Continue'));
    await tester.pump();
    expect(finished, 1);
    expect(gateway.bluetooth, PermissionState.notRequested);
  });

  testWidgets('a refused permission can be retried', (tester) async {
    gateway = FakePermissionGateway(grant: false, delay: Duration.zero);
    await pumpOnboarding(tester, still: true);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allow').first);
    await tester.pumpAndSettle();
    expect(find.text('NOT ALLOWED'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('every page fits with large text', (tester) async {
    await pumpOnboarding(tester, still: true, textScale: 1.4);
    for (var page = 0; page < 4; page++) {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (page < 3) await tester.tap(find.byType(FilledButton));
    }
  });
}
