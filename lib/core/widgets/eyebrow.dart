import 'package:flutter/material.dart';

import '../theme/aelos_type.dart';

/// Small spaced capitals above a section or a value.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = AelosText.of(context).eyebrow;
    return Text(
      text.toUpperCase(),
      style: color == null ? style : style.copyWith(color: color),
    );
  }
}
