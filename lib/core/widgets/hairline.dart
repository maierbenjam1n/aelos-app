import 'package:flutter/material.dart';

import '../theme/aelos_colors.dart';
import '../theme/tokens.dart';

/// Thin horizontal rule. [ornament] adds a small lozenge in the middle, the
/// way a printed programme separates sections.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.ornament = false, this.indent = 0});

  final bool ornament;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final rule = Expanded(child: Container(height: 0.8, color: colors.hairline));
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Row(
        children: [
          rule,
          if (ornament) ...[
            const SizedBox(width: Space.m),
            Transform.rotate(
              angle: 0.785398, // 45°
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.accent, width: 0.9),
                ),
              ),
            ),
            const SizedBox(width: Space.m),
            rule,
          ],
        ],
      ),
    );
  }
}
