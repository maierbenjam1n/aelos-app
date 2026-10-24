import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/aelos_theme.dart';
import 'core/theme/theme_mode.dart';
import 'data/accounts.dart';
import 'data/instruments_notifier.dart';
import 'data/sensor_session.dart';
import 'domain/models/account.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/instrument_detail_screen.dart';
import 'features/impact/alert_host.dart';
import 'features/login/login_screen.dart';
import 'features/luthier/luthier_home_screen.dart';

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
      home: const _RoleRoot(),
    );
  }
}

/// Picks the home screen for the signed-in role, and keeps the live sensor
/// session on the role's live instrument.
class _RoleRoot extends ConsumerWidget {
  const _RoleRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(liveInstrumentIdProvider, (previous, next) async {
      if (next == null || next == previous) return;
      await ref.read(instrumentsProvider.future);
      await ref.read(sessionProvider.notifier).start(next);
    });
    final account = ref.watch(accountProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      child: switch (account?.role) {
        null => const LoginScreen(key: ValueKey('login')),
        AccountRole.owner || AccountRole.renter => DashboardScreen(key: ValueKey(account!.id)),
        AccountRole.luthier => const LuthierHomeScreen(key: ValueKey('luthier')),
      },
    );
  }
}
