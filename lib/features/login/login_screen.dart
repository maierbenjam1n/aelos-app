import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/accounts.dart';
import '../../domain/models/account.dart';

/// Sign-in: choose how you use Aelos. Placeholder until the designed screen
/// lands; the API (signing in through `accountProvider`) stays the same.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.page),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final role in AccountRole.values) ...[
                  OutlinedButton(
                    onPressed: () => ref.read(accountProvider.notifier).signIn(role),
                    child: Text(role.label),
                  ),
                  const SizedBox(height: Space.m),
                ],
              ],
            ),
          ),
        ),
      );
}
