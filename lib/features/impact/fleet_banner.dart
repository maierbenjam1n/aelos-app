import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/eyebrow.dart';
import '../../domain/models/condition_status.dart';

/// A calm in-app banner for a luthier: one of their rentals took a knock.
/// Slides down over whatever is open; never takes over the screen. Swipe
/// up to dismiss; it also leaves by itself.
class FleetBanner extends StatelessWidget {
  const FleetBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.detail,
    required this.severity,
    required this.icon,
    required this.onOpen,
    required this.onDismiss,
  });

  /// E.g. "Fleet alert · 14:32".
  final String eyebrow;

  /// E.g. "Cello, Mirecourt · 7.2 g".
  final String title;

  /// E.g. "Noah Keller · Strong impact recorded".
  final String detail;
  final ConditionStatus severity;
  final IconData icon;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final mark = colors.status(severity);
    const radius = BorderRadius.all(Radii.m);
    return Dismissible(
      key: const ValueKey('fleet-banner'),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: colors.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.hairline, width: 0.8),
        ),
        shadowColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: mark, width: 3)),
          ),
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.xs, Space.m),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: colors.statusTint(severity), shape: BoxShape.circle),
                    child: Icon(icon, size: 18, color: mark),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(eyebrow, color: colors.statusInk(severity)),
                        const SizedBox(height: 2),
                        Text(title, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          detail,
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: onOpen, child: const Text('Open')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
