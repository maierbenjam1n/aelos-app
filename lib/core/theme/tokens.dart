import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Brand colours from the brief. Use [AelosColors] in widgets; these are the
/// raw values it is built from.
abstract final class AelosPalette {
  static const walnut = Color(0xFF2B1F17);
  static const walnutDeep = Color(0xFF1E1611);
  static const walnutRaised = Color(0xFF36281E);
  static const ivory = Color(0xFFF6F0E6);
  static const ivoryLight = Color(0xFFFCF8F2);
  static const varnish = Color(0xFFB8742A);
  static const varnishText = Color(0xFF8F5A1E);
  static const sage = Color(0xFF6E8B6A);
  static const amber = Color(0xFFD9A35B);
  static const oxblood = Color(0xFF9A3B2E);
}

abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page margin.
  static const double page = 20;
}

abstract final class Radii {
  static const s = Radius.circular(8);
  static const m = Radius.circular(14);
  static const l = Radius.circular(22);
  static const pill = Radius.circular(999);
}

/// Calm and confident: ease-out entrances, no overshoot anywhere.
abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 560);
  static const countUp = Duration(milliseconds: 900);
  static const chartDraw = Duration(milliseconds: 1200);

  /// Delay between items rising in sequence.
  static const stagger = Duration(milliseconds: 70);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasis = Cubic(0.2, 0, 0, 1);
}
