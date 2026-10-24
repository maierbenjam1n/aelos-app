import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/theme_mode.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/f_hole.dart';
import '../../core/widgets/hairline.dart';
import '../../data/accounts.dart';
import '../../data/instruments_notifier.dart';
import '../../domain/models/condition_status.dart';
import '../demo_panel/demo_panel.dart';
import '../style_guide/style_guide_screen.dart';
import 'alerts_tab.dart';
import 'fleet_tab.dart';
import 'luthier_fleet.dart';
import 'luthier_widgets.dart';
import 'overview_tab.dart';
import 'reports_tab.dart';

enum LuthierTab {
  overview('Overview', Icons.dashboard_outlined, Icons.dashboard_rounded),
  fleet('Fleet', Icons.view_agenda_outlined, Icons.view_agenda_rounded),
  alerts('Alerts', Icons.notifications_none_rounded, Icons.notifications_rounded),
  reports('Reports', Icons.inbox_outlined, Icons.inbox_rounded);

  const LuthierTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The luthier's home: Overview · Fleet · Alerts · Reports.
class LuthierHomeScreen extends ConsumerStatefulWidget {
  const LuthierHomeScreen({super.key, this.initialTab = LuthierTab.overview});

  final LuthierTab initialTab;

  @override
  ConsumerState<LuthierHomeScreen> createState() => _LuthierHomeScreenState();
}

class _LuthierHomeScreenState extends ConsumerState<LuthierHomeScreen> {
  late LuthierTab _tab = widget.initialTab;

  void _go(LuthierTab tab) => setState(() => _tab = tab);

  void _openDemoPanel() => unawaited(
        showDemoPanel(
          context,
          onOpenStyleGuide: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const StyleGuideScreen()),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(instrumentsProvider);
    final alerts = ref.watch(fleetAlertsProvider);
    final reports = ref.watch(fleetReportsProvider);
    final colors = AelosColors.of(context);

    final body = loaded.when(
      data: (_) => switch (_tab) {
        LuthierTab.overview => OverviewTab(
            onShowFleet: () => _go(LuthierTab.fleet),
            onShowReports: () => _go(LuthierTab.reports),
          ),
        LuthierTab.fleet => const FleetTab(),
        LuthierTab.alerts => const AlertsTab(),
        LuthierTab.reports => const ReportsTab(),
      },
      error: (e, _) => LuthierPage(children: [LuthierEmpty('The fleet could not be loaded. $e')]),
      loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
    );

    final recentActNow = alerts
        .where((a) => a.alert.severity == ConditionStatus.actNow)
        .where((a) => DateTime.now().difference(a.displayTime) < const Duration(hours: 24))
        .length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(onLongPressMark: _openDemoPanel),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                child: KeyedSubtree(key: ValueKey(_tab), child: body),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _NavBar(
        selected: _tab,
        onSelected: _go,
        badges: {
          LuthierTab.alerts: recentActNow,
          LuthierTab.reports: reports.where((r) => r.needsReview).length,
        },
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.onLongPressMark});

  final VoidCallback onLongPressMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final account = ref.watch(accountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page - Space.xs, Space.xs),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onLongPressMark,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Row(
                children: [
                  FHole(height: 26, color: colors.accent),
                  const SizedBox(width: Space.s),
                  Text('Aelos', style: text.titleLarge),
                  const SizedBox(width: Space.m),
                  Container(width: 0.8, height: 16, color: colors.hairline),
                  const SizedBox(width: Space.m),
                  const Eyebrow('Workshop'),
                ],
              ),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: 'Account',
            child: InkResponse(
              radius: 26,
              onTap: () => _showAccountSheet(context),
              child: Padding(
                padding: const EdgeInsets.all(Space.xs),
                child: Monogram(account?.name ?? '', size: 38, filled: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showAccountSheet(BuildContext context) => unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: AelosColors.of(context).surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radii.l)),
        builder: (_) => const _AccountSheet(),
      ),
    );

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final account = ref.watch(accountProvider);
    final workshop = ref.watch(workshopProvider);
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Monogram(account?.name ?? '', size: 56, filled: true),
                const SizedBox(width: Space.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account?.name ?? '', style: text.headlineMedium),
                      Text('Master luthier · ${workshop?.workshop ?? ''}', style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.l),
            const Hairline(ornament: true),
            const SizedBox(height: Space.s),
            if (workshop != null) ...[
              _SheetRow(icon: Icons.storefront_outlined, label: '${workshop.workshop} · ${workshop.city}'),
              _SheetRow(icon: Icons.call_outlined, label: workshop.phone),
              _SheetRow(icon: Icons.mail_outline_rounded, label: workshop.email),
            ],
            _SheetRow(
              icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              label: dark ? 'Light appearance' : 'Dark appearance',
              onTap: () => ref.read(themeModeProvider.notifier).toggle(brightness),
            ),
            const SizedBox(height: Space.l),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(accountProvider.notifier).signOut();
              },
              icon: Icon(Icons.logout_rounded, size: 20, color: colors.accent),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radii.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.m - 2),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textMuted),
            const SizedBox(width: Space.m),
            Expanded(child: Text(label, style: text.bodyMedium)),
            if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: colors.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Four quiet tabs; the selected one is inked, with a short varnish rule
/// above it like a programme's section mark.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.selected, required this.onSelected, required this.badges});

  final LuthierTab selected;
  final ValueChanged<LuthierTab> onSelected;
  final Map<LuthierTab, int> badges;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.hairline, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (final tab in LuthierTab.values)
                Expanded(
                  child: Semantics(
                    selected: tab == selected,
                    button: true,
                    label: tab.label,
                    child: InkResponse(
                      onTap: () => onSelected(tab),
                      highlightShape: BoxShape.rectangle,
                      containedInkWell: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: Motion.medium,
                            curve: Motion.emphasis,
                            width: tab == selected ? 22 : 0,
                            height: 2,
                            color: colors.accent,
                          ),
                          const SizedBox(height: Space.s),
                          Badge(
                            isLabelVisible: (badges[tab] ?? 0) > 0,
                            backgroundColor: colors.accent,
                            textColor: AelosPalette.ivory,
                            label: Text('${badges[tab] ?? 0}'),
                            offset: const Offset(8, -5),
                            child: Icon(
                              tab == selected ? tab.selectedIcon : tab.icon,
                              size: 22,
                              color: tab == selected ? colors.text : colors.textFaint,
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          AnimatedDefaultTextStyle(
                            duration: Motion.medium,
                            style: text.labelMedium!.copyWith(
                              color: tab == selected ? colors.text : colors.textFaint,
                              fontWeight: tab == selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                            child: Text(tab.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
