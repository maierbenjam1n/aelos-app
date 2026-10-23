import 'package:flutter/material.dart';

import '../theme/aelos_type.dart';
import '../theme/tokens.dart';

enum ReadingSize { hero, large, small }

/// A number with its unit that counts up on first build and glides to new
/// values. Tabular figures keep the width steady while it moves.
class ReadingValue extends StatefulWidget {
  const ReadingValue({
    super.key,
    required this.value,
    required this.unit,
    this.decimals = 1,
    this.size = ReadingSize.large,
    this.countFrom,
  });

  final double value;
  final String unit;
  final int decimals;
  final ReadingSize size;

  /// Start of the first count-up. Defaults to 85 % of [value], which reads as
  /// "settling in" rather than counting from zero.
  final double? countFrom;

  @override
  State<ReadingValue> createState() => _ReadingValueState();
}

class _ReadingValueState extends State<ReadingValue> {
  late double _from = widget.countFrom ?? widget.value * 0.85;

  @override
  void didUpdateWidget(ReadingValue old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value;
  }

  @override
  Widget build(BuildContext context) {
    final text = AelosText.of(context);
    final (number, unitStyle, gap) = switch (widget.size) {
      ReadingSize.hero => (text.readingHero, text.unit.copyWith(fontSize: 26), 6.0),
      ReadingSize.large => (text.readingLarge, text.unit.copyWith(fontSize: 18), 4.0),
      ReadingSize.small => (text.readingSmall, text.unit.copyWith(fontSize: 14), 2.0),
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value),
      duration: Motion.countUp,
      curve: Motion.emphasis,
      builder: (context, v, _) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: v.toStringAsFixed(widget.decimals), style: number),
            WidgetSpan(child: SizedBox(width: gap)),
            TextSpan(text: widget.unit, style: unitStyle),
          ],
        ),
        semanticsLabel:
            '${widget.value.toStringAsFixed(widget.decimals)} ${widget.unit}',
      ),
    );
  }
}
