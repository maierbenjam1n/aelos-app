import 'package:aelos/core/theme/aelos_theme.dart';
import 'package:aelos/domain/models/device_info.dart';
import 'package:aelos/features/pairing/pairing_controller.dart';
import 'package:aelos/features/pairing/pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_sensor_connection.dart';

Widget _app(Widget home) => MaterialApp(theme: AelosTheme.dark, home: home);

/// A small phone (360×640): the layout must fit without overflow.
void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 1920)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('scan, pick a sensor, link it and continue', (tester) async {
    _phone(tester);
    final connection = FakeSensorConnection();
    DeviceInfo? paired;
    await tester.pumpWidget(
      _app(PairingScreen(connection: connection, onPaired: (i) => paired = i)),
    );

    expect(find.text('Looking for your sensor'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sensor found'), findsOneWidget);

    await tester.tap(find.text('Aelos-1AFB'));
    await tester.pump();
    expect(find.text('Linking Aelos-1AFB'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Linked'), findsOneWidget);
    expect(find.text('7E18 88D9 2072 6415'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    expect(paired?.id, '1AFB');
    expect(connection.connected, ['a']);
  });

  testWidgets('a failed connection offers a retry', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(PairingScreen(connection: FakeSensorConnection(failConnect: true), onPaired: (_) {})),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Aelos-1AFB'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Not linked'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  test('key fingerprint groups the first 8 bytes', () {
    expect(keyFingerprint(testDeviceInfo.publicKey), '7E18 88D9 2072 6415');
  });
}
