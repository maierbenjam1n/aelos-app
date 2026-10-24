import 'package:flutter/material.dart';

import '../theme/aelos_colors.dart';
import '../theme/aelos_type.dart';

/// A person's initials in a small varnish-ringed medallion, set in the serif.
class Monogram extends StatelessWidget {
  const Monogram(this.name, {super.key, this.size = 40});

  final String name;
  final double size;

  static String initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.accent.withValues(alpha: 0.12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.55), width: 0.9),
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          fontFamily: Fonts.serif,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.42,
          height: 1,
          letterSpacing: size * 0.01,
          color: colors.accentInk,
        ),
      ),
    );
  }
}
