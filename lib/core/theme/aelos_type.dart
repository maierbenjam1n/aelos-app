
import 'package:flutter/material.dart';

/// Font families declared in pubspec.yaml.
abstract final class Fonts {
  static const serif = 'CormorantGaramond';
  static const sans = 'Inter';
}

const _tabular = [FontFeature.tabularFigures()];

/// Cormorant Garamond for headings, Inter for everything that reads as data.
TextTheme aelosTextTheme(Color text, Color muted) => TextTheme(
      displayLarge: _serif(52, FontWeight.w500, text, height: 1.05, spacing: -0.5),
      displayMedium: _serif(40, FontWeight.w500, text, height: 1.1, spacing: -0.3),
      displaySmall: _serif(34, FontWeight.w500, text, height: 1.12),
      headlineLarge: _serif(30, FontWeight.w500, text, height: 1.15),
      headlineMedium: _serif(26, FontWeight.w500, text, height: 1.2),
      headlineSmall: _serif(23, FontWeight.w600, text, height: 1.2),
      titleLarge: _serif(21, FontWeight.w600, text, height: 1.25),
      titleMedium: _sans(16, FontWeight.w500, text, height: 1.35),
      titleSmall: _sans(14, FontWeight.w500, text, height: 1.35),
      bodyLarge: _sans(16, FontWeight.w400, text, height: 1.5),
      bodyMedium: _sans(14, FontWeight.w400, text, height: 1.5),
      bodySmall: _sans(12.5, FontWeight.w400, muted, height: 1.45),
      labelLarge: _sans(14, FontWeight.w500, text, spacing: 0.2),
      labelMedium: _sans(12, FontWeight.w500, muted, spacing: 0.3),
      labelSmall: _sans(11, FontWeight.w600, muted, spacing: 1.4),
    );

/// Styles outside Material's scale: big readings and small eyebrows.
@immutable
final class AelosText extends ThemeExtension<AelosText> {
  const AelosText({
    required this.readingHero,
    required this.readingLarge,
    required this.readingSmall,
    required this.unit,
    required this.eyebrow,
    required this.note,
  });

  factory AelosText.forColors(Color text, Color muted) => AelosText(
        readingHero: _sans(76, FontWeight.w300, text, height: 1, spacing: -2.5)
            .copyWith(fontFeatures: _tabular),
        readingLarge: _sans(44, FontWeight.w300, text, height: 1, spacing: -1.2)
            .copyWith(fontFeatures: _tabular),
        readingSmall: _sans(20, FontWeight.w400, text, height: 1.1, spacing: -0.2)
            .copyWith(fontFeatures: _tabular),
        unit: _sans(16, FontWeight.w400, muted, height: 1),
        eyebrow: _sans(11, FontWeight.w600, muted, spacing: 1.8),
        note: _serif(18, FontWeight.w400, muted, height: 1.35)
            .copyWith(fontStyle: FontStyle.italic),
      );

  /// The one big number on a screen, e.g. live humidity.
  final TextStyle readingHero;

  /// Card-level readings on the dashboard.
  final TextStyle readingLarge;

  /// Inline values in lists and timelines.
  final TextStyle readingSmall;

  /// Units next to a reading: `%`, `°C`, `g`.
  final TextStyle unit;

  /// Small spaced capitals above a section or value. Uppercase the text.
  final TextStyle eyebrow;

  /// Italic serif aside, e.g. "Tighter limits applied".
  final TextStyle note;

  static AelosText of(BuildContext context) =>
      Theme.of(context).extension<AelosText>()!;

  @override
  AelosText copyWith() => this;

  @override
  AelosText lerp(AelosText? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AelosText(
      readingHero: l(readingHero, other.readingHero),
      readingLarge: l(readingLarge, other.readingLarge),
      readingSmall: l(readingSmall, other.readingSmall),
      unit: l(unit, other.unit),
      eyebrow: l(eyebrow, other.eyebrow),
      note: l(note, other.note),
    );
  }
}

TextStyle _serif(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
  double spacing = 0,
}) =>
    TextStyle(
      fontFamily: Fonts.serif,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
    );

TextStyle _sans(
  double size,
  FontWeight weight,
  Color color, {
  double? height,
  double spacing = 0,
}) =>
    TextStyle(
      fontFamily: Fonts.sans,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
    );
