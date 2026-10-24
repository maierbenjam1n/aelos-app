import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/aelos_theme.dart';
import 'core/theme/theme_mode.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/instrument_detail_screen.dart';
import 'features/impact/alert_host.dart';

void main() {
  runApp(const ProviderScope(child: AelosApp()));
}

class AelosApp extends ConsumerWidget {
  const AelosApp({super.key});

  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Aelos',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      builder: (context, child) => AlertHost(
        navigatorKey: _navigatorKey,
        onOpenInstrument: (instrumentId) {
          final navigator = _navigatorKey.currentState;
          if (navigator == null) return;
          unawaited(
            navigator.push<void>(
              MaterialPageRoute<void>(
                builder: (_) =>
                    InstrumentDetailScreen(instrumentId: instrumentId),
              ),
            ),
          );
        },
        child: child ?? const SizedBox.shrink(),
      ),
      theme: AelosTheme.light,
      darkTheme: AelosTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: const DashboardScreen(),
    );
  }
}
