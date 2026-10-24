import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/theme_mode.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/monogram.dart';
import '../../data/accounts.dart';
import '../../domain/models/account.dart';
import 'account_labels.dart';

/// An extra row in the account menu, e.g. the design-system preview.
typedef AccountMenuAction = ({IconData icon, String label, VoidCallback onTap});

/// The signed-in person's monogram for an app bar. Opens a sheet with the
/// account, light/dark appearance, any [actions], and sign-out.
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key, this.actions = const []});

  final List<AccountMenuAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    if (account == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Account',
      onPressed: () => unawaited(
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          backgroundColor: AelosColors.of(context).surfaceRaised,
          builder: (_) => _AccountSheet(account: account, actions: actions),
        ),
      ),
      icon: Monogram(account.name, size: 32),
    );
  }
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet({required this.account, required this.actions});

  final Account account;
  final List<AccountMenuAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final navigator = Navigator.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Monogram(account.name, size: 52),
                const SizedBox(width: Space.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name, style: text.headlineSmall),
                      const SizedBox(height: 2),
                      Text(account.roleLine, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.l + 2),
            const Hairline(),
            _MenuRow(
              icon: brightness == Brightness.dark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              label: 'Dark appearance',
              onTap: () => ref.read(themeModeProvider.notifier).toggle(brightness),
              trailing: Switch(
                value: brightness == Brightness.dark,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggle(brightness),
              ),
            ),
            for (final action in actions)
              _MenuRow(
                icon: action.icon,
                label: action.label,
                onTap: () {
                  navigator.pop();
                  action.onTap();
                },
                trailing: Icon(Icons.chevron_right_rounded, color: colors.textFaint),
              ),
            const Hairline(),
            _MenuRow(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              detail: account.role == AccountRole.luthier
                  ? 'Back to the choice of roles'
                  : 'Choose another way to use Aelos',
              onTap: () {
                navigator.popUntil((route) => route.isFirst);
                ref.read(accountProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radii.s),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s),
          child: Row(
            children: [
              Icon(icon, size: 22, color: colors.accent),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: text.titleMedium),
                    if (detail case final detail?) ...[
                      const SizedBox(height: 2),
                      Text(detail, style: text.bodySmall),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
