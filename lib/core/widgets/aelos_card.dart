import 'package:flutter/material.dart';

import '../theme/aelos_colors.dart';
import '../theme/tokens.dart';

/// Surface with a hairline border and no elevation; tappable if [onTap] is set.
class AelosCard extends StatelessWidget {
  const AelosCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.l + 2),
    this.onTap,
    this.raised = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Use the raised surface, e.g. for a card on top of another card.
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    const radius = BorderRadius.all(Radii.m);
    return Material(
      color: raised ? colors.surfaceRaised : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colors.hairline, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
