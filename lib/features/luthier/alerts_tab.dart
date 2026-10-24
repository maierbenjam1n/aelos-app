import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/rise_in.dart';
import '../../core/widgets/status_badge.dart';
import '../../domain/models/condition_status.dart';
import 'fleet_instrument_screen.dart';
import 'luthier_fleet.dart';
import 'luthier_format.dart';
import 'luthier_widgets.dart';

enum _Filter { all, actNow, attention }

/// The combined alert feed across the fleet, newest first, by day.
class AlertsTab extends ConsumerStatefulWidget {
  const AlertsTab({super.key});

  @override
  ConsumerState<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends ConsumerState<AlertsTab> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(fleetAlertsProvider);
    final actNow = all.where((a) => a.alert.severity == ConditionStatus.actNow).length;
    final shown = [
      for (final a in all)
        if (switch (_filter) {
          _Filter.all => true,
          _Filter.actNow => a.alert.severity == ConditionStatus.actNow,
          _Filter.attention => a.alert.severity == ConditionStatus.attention,
        })
          a,
    ];

    final children = <Widget>[];
    String? day;
    var i = 2;
    for (final a in shown) {
      final heading = LuthierFormat.dayHeading(a.displayTime);
      if (heading != day) {
        day = heading;
        if (children.isNotEmpty) children.add(const SizedBox(height: Space.m));
        children.add(SectionHeader(heading).riseIn(i++));
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: FleetAlertTile(
            alert: a,
            onTap: () => FleetInstrumentScreen.open(context, a.entry.id),
          ),
        ).riseIn(i++),
      );
    }

    return LuthierPage(
      children: [
        PageHeading(
          eyebrow: 'Across the fleet',
          title: 'Alerts',
          subtitle: '${all.length} ${all.length == 1 ? 'alert' : 'alerts'} in the signed histories'
              '${actNow == 0 ? '' : ' · $actNow to act on'}',
        ).riseIn(0),
        const SizedBox(height: Space.xl),
        LuthierSegmented<_Filter>(
          segments: const [
            (_Filter.all, 'All'),
            (_Filter.actNow, 'Act now'),
            (_Filter.attention, 'Attention'),
          ],
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ).riseIn(1),
        const SizedBox(height: Space.xl),
        if (shown.isEmpty) const LuthierEmpty('No alerts of this kind. The histories are calm.'),
        ...children,
      ],
    );
  }
}

/// One alert: severity (colour, icon and word), instrument and renter, why
/// it fired, and what to do.
class FleetAlertTile extends StatelessWidget {
  const FleetAlertTile({super.key, required this.alert, this.onTap, this.showInstrument = true});

  final FleetAlert alert;
  final VoidCallback? onTap;
  final bool showInstrument;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final a = alert.alert;
    final rental = alert.entry.rental;
    final who = rental.inWorkshop ? 'In the workshop' : rental.renterName ?? '';
    return AelosCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: colors.statusTint(a.severity), shape: BoxShape.circle),
            child: Icon(a.severity.icon, size: 20, color: colors.status(a.severity)),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Eyebrow(a.severity.label, color: colors.statusInk(a.severity)),
                    ),
                    Text(
                      showInstrument
                          ? LuthierFormat.clock(alert.displayTime)
                          : LuthierFormat.when(alert.displayTime),
                      style: text.labelMedium!.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(a.title, style: text.titleMedium),
                if (showInstrument)
                  Text(
                    '${alert.entry.data.instrument.name} · $who',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                const SizedBox(height: Space.s),
                Text(a.why, style: text.bodyMedium),
                const SizedBox(height: Space.s),
                Container(
                  padding: const EdgeInsets.only(left: Space.m),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: colors.accent.withValues(alpha: 0.5), width: 1.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('What to do'),
                      const SizedBox(height: 2),
                      Text(a.whatToDo, style: text.bodySmall),
                    ],
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
