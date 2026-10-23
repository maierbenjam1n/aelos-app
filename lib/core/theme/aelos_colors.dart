import 'package:flutter/material.dart';

import '../../domain/models/condition_status.dart';
import 'tokens.dart';

/// Semantic colours for one brightness. `*Ink` colours are for text (WCAG
/// 4.5:1 on background and surface); status colours are for icons and marks
/// (3:1); `*Tint` colours are fills behind ink. test/core/contrast_test.dart
/// enforces the ratios.
@immutable
final class AelosColors extends ThemeExtension<AelosColors> {
  const AelosColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.hairline,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentInk,
    required this.calm,
    required this.calmInk,
    required this.attention,
    required this.attentionInk,
    required this.actNow,
    required this.actNowInk,
  });

  static const light = AelosColors(
    background: AelosPalette.ivory,
    surface: AelosPalette.ivoryLight,
    surfaceRaised: Color(0xFFFFFFFF),
    hairline: Color(0x262B1F17),
    text: AelosPalette.walnut,
    textMuted: Color(0xFF6E5E50),
    textFaint: Color(0xFF8C7B6B),
    accent: AelosPalette.varnish,
    accentInk: AelosPalette.varnishText,
    calm: AelosPalette.sage,
    calmInk: Color(0xFF4D6A49),
    // The brief's amber is too light for marks on ivory; it stays in the tint.
    attention: Color(0xFFA06B24),
    attentionInk: AelosPalette.varnishText,
    actNow: AelosPalette.oxblood,
    actNowInk: AelosPalette.oxblood,
  );

  static const dark = AelosColors(
    background: AelosPalette.walnutDeep,
    surface: AelosPalette.walnut,
    surfaceRaised: AelosPalette.walnutRaised,
    hairline: Color(0x29F6F0E6),
    text: AelosPalette.ivory,
    textMuted: Color(0xFFBFB2A3),
    textFaint: Color(0xFF8F8172),
    accent: AelosPalette.varnish,
    accentInk: AelosPalette.amber,
    calm: Color(0xFF93B08E),
    calmInk: Color(0xFF93B08E),
    attention: AelosPalette.amber,
    attentionInk: AelosPalette.amber,
    actNow: Color(0xFFE07A66),
    actNowInk: Color(0xFFE07A66),
  );

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color hairline;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color accentInk;
  final Color calm;
  final Color calmInk;
  final Color attention;
  final Color attentionInk;
  final Color actNow;
  final Color actNowInk;

  static AelosColors of(BuildContext context) =>
      Theme.of(context).extension<AelosColors>()!;

  /// Icon/mark colour for [status].
  Color status(ConditionStatus status) => switch (status) {
        ConditionStatus.calm => calm,
        ConditionStatus.attention => attention,
        ConditionStatus.actNow => actNow,
      };

  /// Text colour for [status].
  Color statusInk(ConditionStatus status) => switch (status) {
        ConditionStatus.calm => calmInk,
        ConditionStatus.attention => attentionInk,
        ConditionStatus.actNow => actNowInk,
      };

  /// Quiet fill behind a status mark, from the brief's pure status colours.
  Color statusTint(ConditionStatus status) => switch (status) {
        ConditionStatus.calm => AelosPalette.sage,
        ConditionStatus.attention => AelosPalette.amber,
        ConditionStatus.actNow => AelosPalette.oxblood,
      }
          .withValues(alpha: 0.16);

  @override
  AelosColors copyWith() => this;

  @override
  AelosColors lerp(AelosColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AelosColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      hairline: l(hairline, other.hairline),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      textFaint: l(textFaint, other.textFaint),
      accent: l(accent, other.accent),
      accentInk: l(accentInk, other.accentInk),
      calm: l(calm, other.calm),
      calmInk: l(calmInk, other.calmInk),
      attention: l(attention, other.attention),
      attentionInk: l(attentionInk, other.attentionInk),
      actNow: l(actNow, other.actNow),
      actNowInk: l(actNowInk, other.actNowInk),
    );
  }
}
