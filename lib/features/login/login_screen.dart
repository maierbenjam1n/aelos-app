import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/f_hole.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/monogram.dart';
import '../../core/widgets/rise_in.dart';
import '../../core/widgets/role_motif.dart';
import '../../data/accounts.dart';
import '../../domain/models/account.dart';
import 'account_labels.dart';

/// Sign-in: choose how you use Aelos, then confirm the demo account for that
/// role with one tap. Signing in through `accountProvider` lets `main.dart`
/// route to the role's home.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialRole});

  /// Open on the confirm step for this role. For screenshots.
  final AccountRole? initialRole;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late AccountRole? _chosen = widget.initialRole;

  void _choose(AccountRole? role) => setState(() => _chosen = role);

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    return PopScope(
      canPop: chosen == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _choose(null);
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: Motion.slow,
            switchInCurve: Motion.enter,
            switchOutCurve: Motion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.015),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: chosen == null
                ? _ChooseStage(key: const ValueKey('choose'), onChoose: _choose)
                : _ConfirmStage(
                    key: ValueKey(chosen),
                    role: chosen,
                    onBack: () => _choose(null),
                    onContinue: () =>
                        ref.read(accountProvider.notifier).signIn(chosen),
                  ),
          ),
        ),
      ),
    );
  }
}

const _maxWidth = 440.0;

/// Lays [children] out centred on tall screens and scrolls on short ones.
class _FitOrScroll extends StatelessWidget {
  const _FitOrScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: math.max(Space.page, (constraints.maxWidth - _maxWidth) / 2),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: children,
            ),
          ),
        ),
      );
}

const _choices = [
  (AccountRole.owner, 'Look after it yourself, with your own Aelos sensor.'),
  (AccountRole.renter, 'Your luthier provides the sensor and cares for it with you.'),
  (AccountRole.luthier, 'Manage your rental fleet and the people who play it.'),
];

class _ChooseStage extends StatelessWidget {
  const _ChooseStage({super.key, required this.onChoose});

  final ValueChanged<AccountRole> onChoose;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final animate = !MediaQuery.disableAnimationsOf(context);
    Widget rise(Widget w, int i) => animate ? w.riseIn(i) : w;
    // Short phones: a smaller mark and tighter rhythm keep all three choices
    // and the footer on one screen.
    final compact = MediaQuery.sizeOf(context).height < 720;
    final gap = compact ? Space.m : Space.l + 2;

    return _FitOrScroll(
      children: [
        SizedBox(height: compact ? Space.l : Space.xxl),
        Column(
          children: [
            _Mark(large: true, height: compact ? 52 : 72),
            SizedBox(height: compact ? Space.l : Space.xl),
            rise(
              Text(
                'The quiet keeper\nof fine instruments',
                style: text.displaySmall,
                textAlign: TextAlign.center,
              ),
              1,
            ),
            SizedBox(height: gap),
            rise(const SizedBox(width: 96, child: Hairline(ornament: true)), 2),
            SizedBox(height: gap),
            rise(Eyebrow('How will you use Aelos?', color: colors.accentInk), 3),
            SizedBox(height: gap),
            for (final (i, (role, line)) in _choices.indexed) ...[
              if (i > 0) const SizedBox(height: Space.m),
              rise(
                _ChoiceCard(
                  role: role,
                  line: line,
                  delay: Motion.stagger * (5 + i * 2),
                  onTap: () => onChoose(role),
                ),
                4 + i,
              ),
            ],
          ],
        ),
        Padding(
          padding: EdgeInsets.only(
            top: compact ? Space.l : Space.xxl,
            bottom: Space.l,
          ),
          child: Text(
            'Demo accounts  ·  no password needed',
            style: text.bodySmall!.copyWith(color: colors.textFaint),
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.role,
    required this.line,
    required this.delay,
    required this.onTap,
  });

  final AccountRole role;
  final String line;
  final Duration delay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: role.label,
      excludeSemantics: true,
      child: AelosCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.m, Space.l),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 56,
              child: RoleMotif(role, size: 56, animate: true, delay: delay),
            ),
            const SizedBox(width: Space.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.label, style: text.titleLarge),
                  const SizedBox(height: Space.xs - 1),
                  Text(
                    line,
                    style: text.bodySmall!.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            Icon(Icons.arrow_forward_rounded, size: 18, color: colors.textFaint),
          ],
        ),
      ),
    );
  }
}

/// The f-hole and the spaced wordmark.
class _Mark extends StatelessWidget {
  const _Mark({this.large = false, this.height = 72});

  final bool large;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final wordmark = AelosText.of(context).eyebrow.copyWith(
          color: colors.text,
          fontSize: large ? 13 : 11,
          letterSpacing: large ? 6 : 4,
        );
    if (!large) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FHole(height: 18, color: colors.accent),
          const SizedBox(width: Space.s + 2),
          Text('AELOS', style: wordmark),
        ],
      );
    }
    final animate = !MediaQuery.disableAnimationsOf(context);
    final mark = SizedBox(
      width: height / 4,
      height: height,
      child: animate
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Motion.chartDraw,
              curve: Motion.emphasis,
              builder: (_, p, _) => CustomPaint(
                painter: FHolePainter(colors.accent, progress: p),
              ),
            )
          : FHole(height: height, color: colors.accent),
    );
    return Column(
      children: [
        mark,
        const SizedBox(height: Space.l + 2),
        // Letter spacing trails the last letter; pad the front to match.
        Padding(
          padding: EdgeInsets.only(left: wordmark.letterSpacing!),
          child: Text('AELOS', style: wordmark),
        ),
      ],
    );
  }
}

class _ConfirmStage extends ConsumerWidget {
  const _ConfirmStage({
    super.key,
    required this.role,
    required this.onBack,
    required this.onContinue,
  });

  final AccountRole role;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final account = DemoDirectory.accountFor(role);
    final first = account.name.split(' ').first;
    final animate = !MediaQuery.disableAnimationsOf(context);
    Widget rise(Widget w, int i) => animate ? w.riseIn(i) : w;
    final compact = MediaQuery.sizeOf(context).height < 720;
    final motif = compact ? 80.0 : 120.0;
    final subtitle = switch (role) {
      AccountRole.owner =>
        'Your instruments and their signed history, looked after by you.',
      AccountRole.renter =>
        'Your luthier provided the sensor and looks after the instrument with you.',
      AccountRole.luthier =>
        'Your rental fleet, its renters and their reports, in one place.',
    };

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: Space.xs),
              IconButton(
                tooltip: 'Choose another way',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              const _Mark(),
              const Spacer(),
              const SizedBox(width: 48 + Space.xs),
            ],
          ),
        ),
        Expanded(
          child: _FitOrScroll(
            children: [
              SizedBox(height: compact ? Space.s : Space.l),
              Column(
                children: [
                  SizedBox.square(
                    dimension: motif,
                    child: RoleMotif(role, size: motif, animate: true),
                  ),
                  SizedBox(height: compact ? Space.l : Space.xl),
                  rise(Eyebrow(role.label, color: colors.accentInk), 1),
                  const SizedBox(height: Space.m),
                  rise(
                    Text(
                      'Welcome, $first',
                      style: compact ? text.displaySmall : text.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    2,
                  ),
                  const SizedBox(height: Space.s),
                  rise(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        subtitle,
                        style: text.bodyLarge!.copyWith(color: colors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    3,
                  ),
                  SizedBox(height: compact ? Space.l : Space.xl),
                  rise(_AccountCard(account: account), 4),
                ],
              ),
              SizedBox(height: compact ? Space.s : Space.l),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.page,
            Space.s,
            Space.page,
            Space.l,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              children: [
                rise(
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onContinue,
                      child: Text('Continue as $first'),
                    ),
                  ),
                  5,
                ),
                const SizedBox(height: Space.m),
                Text(
                  'Demo account  ·  no password needed',
                  style: text.bodySmall!.copyWith(color: colors.textFaint),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final rentals = ref.watch(rentalsProvider);
    final luthier = account.luthier;
    final rental = rentals.where((r) => r.renterId == account.id).firstOrNull;
    final fleet = rentals.where((r) => r.luthierId == account.luthierId).toList();
    final out = fleet.where((r) => !r.inWorkshop).length;

    final details = <(String, String)>[
      ...switch (account.role) {
        AccountRole.owner => const [
            ('Sensor', 'Paired and kept by you'),
            ('History', 'Signed by the sensor'),
          ],
        AccountRole.renter => [
            if (luthier != null) ('Luthier', luthier.master),
            if (rental?.plan case final plan?) ('Plan', plan),
            if (rental?.since case final since?) ('Since', formatDay(since)),
          ],
        AccountRole.luthier => [
            if (luthier != null) ('Workshop', '${luthier.workshop} · ${luthier.city}'),
            (
              'Fleet',
              '${fleet.length} instrument${fleet.length == 1 ? '' : 's'}'
                  ' · $out rented out',
            ),
          ],
      },
    ];

    return AelosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Monogram(account.name, size: 48),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(account.roleLine, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          const Hairline(),
          for (final (label, value) in details)
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Eyebrow(label),
                  const SizedBox(width: Space.l),
                  Expanded(
                    child: Text(
                      value,
                      style: text.bodyMedium,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
