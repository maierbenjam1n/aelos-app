import 'package:flutter/material.dart';

import '../../domain/models/condition_status.dart';
import '../theme/aelos_colors.dart';
import '../theme/tokens.dart';

extension ConditionStatusLabels on ConditionStatus {
  /// Status is never colour alone: always colour + icon + this word.
  String get label => switch (this) {
        ConditionStatus.calm => 'Calm',
        ConditionStatus.attention => 'Needs attention',
        ConditionStatus.actNow => 'Act now',
      };

  IconData get icon => switch (this) {
        ConditionStatus.calm => Icons.check_circle_outline_rounded,
        ConditionStatus.attention => Icons.warning_amber_rounded,
        ConditionStatus.actNow => Icons.report_outlined,
      };
}

/// Pill with icon and word. Cross-fades when [status] changes.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.large = false});

  final ConditionStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      child: DecoratedBox(
        key: ValueKey(status),
        decoration: BoxDecoration(
          color: colors.statusTint(status),
          borderRadius: const BorderRadius.all(Radii.pill),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: large ? Space.m + 2 : Space.m - 2,
            vertical: large ? Space.s : Space.xs + 1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, size: large ? 20 : 16, color: colors.status(status)),
              SizedBox(width: large ? Space.s : Space.xs + 2),
              Text(
                status.label,
                style: (large ? text.titleSmall : text.labelMedium)!
                    .copyWith(color: colors.statusInk(status)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
