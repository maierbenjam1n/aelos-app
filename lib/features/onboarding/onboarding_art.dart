import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/f_hole.dart';

enum OnboardingArtKind {
  climate(Duration(seconds: 8), 0.3),
  impact(Duration(seconds: 6), 0.46),
  seal(Duration(seconds: 8), 0.2);

  const OnboardingArtKind(this.period, this.stillFrame);

  /// Length of one seamless loop.
  final Duration period;

  /// Loop position shown when animations are disabled: a frame that tells the
  /// story on its own (for the impact, the ripple mid-way).
  final double stillFrame;
}

/// One onboarding illustration. Draws itself in when [active] turns true, then
/// loops quietly; holds a single still frame if the system disables animation.
class OnboardingArt extends StatefulWidget {
  const OnboardingArt({super.key, required this.kind, required this.active});

  final OnboardingArtKind kind;
  final bool active;

  @override
  State<OnboardingArt> createState() => _OnboardingArtState();
}

class _OnboardingArtState extends State<OnboardingArt>
    with TickerProviderStateMixin {
  late final _draw = AnimationController(
    vsync: this,
    duration: Motion.chartDraw * 1.5,
  );
  late final _loop = AnimationController(
    vsync: this,
    duration: widget.kind.period,
  );
  bool _still = false;
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(OnboardingArt old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (_still) {
      _running = false;
      _loop.stop();
      _draw.value = widget.active ? 1 : 0;
      _loop.value = widget.kind.stillFrame;
    } else if (widget.active && !_running) {
      _running = true;
      _draw.forward(from: 0);
      _loop
        ..value = 0
        ..repeat();
    } else if (!widget.active && _running) {
      _running = false;
      _loop.stop();
      _draw.value = 0;
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ArtPalette.of(context);
    final painter = switch (widget.kind) {
      OnboardingArtKind.climate => _ClimatePainter(_draw, _loop, palette),
      OnboardingArtKind.impact => _ImpactPainter(_draw, _loop, palette),
      OnboardingArtKind.seal => _SealPainter(_draw, _loop, palette),
    };
    return RepaintBoundary(
      child: CustomPaint(painter: painter, size: Size.infinite),
    );
  }
}

class _ArtPalette {
  _ArtPalette.of(BuildContext context)
    : this._(AelosColors.of(context), AelosText.of(context).eyebrow);

  _ArtPalette._(AelosColors c, this.label)
    : ink = c.text,
      accent = c.accent,
      accentInk = c.accentInk,
      faint = c.textFaint,
      hairline = c.hairline,
      ground = c.background;

  final Color ink;
  final Color accent;
  final Color accentInk;
  final Color faint;
  final Color hairline;
  final Color ground;
  final TextStyle label;

  @override
  bool operator ==(Object other) =>
      other is _ArtPalette && other.ink == ink && other.ground == ground;

  @override
  int get hashCode => Object.hash(ink, ground);
}

/// Shared plumbing: paints into the centred square, reads both animations.
abstract class _ArtPainter extends CustomPainter {
  _ArtPainter(this.draw, this.loop, this.palette)
    : super(repaint: Listenable.merge([draw, loop]));

  final Animation<double> draw;
  final Animation<double> loop;
  final _ArtPalette palette;

  void paintSquare(Canvas canvas, double s);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    canvas
      ..save()
      ..translate((size.width - s) / 2, (size.height - s) / 2);
    paintSquare(canvas, s);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.palette != palette;

  /// [d] remapped to 0–1 over [start, end], eased in and out.
  static double phase(double d, double start, double end) => Curves
      .easeInOutCubic
      .transform(((d - start) / (end - start)).clamp(0.0, 1.0));

  static Paint stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color
    ..isAntiAlias = true;

  /// The first [fraction] of [path], for drawing lines in.
  static Path partial(Path path, double fraction) {
    if (fraction >= 1) return path;
    final out = Path();
    if (fraction <= 0) return out;
    for (final m in path.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * fraction), Offset.zero);
    }
    return out;
  }

  static void fHole(
    Canvas canvas,
    Offset centre,
    double height,
    Color color,
    double progress,
  ) {
    final size = Size(height / 4, height);
    canvas
      ..save()
      ..translate(centre.dx - size.width / 2, centre.dy - size.height / 2);
    FHolePainter(color, progress: progress).paint(canvas, size);
    canvas.restore();
  }
}

/// Page 1: an f-hole with humidity contour lines breathing around it, like an
/// isobar map of the air inside the case.
class _ClimatePainter extends _ArtPainter {
  _ClimatePainter(super.draw, super.loop, super.palette);

  static const _rings = 6;

  @override
  void paintSquare(Canvas canvas, double s) {
    final d = draw.value;
    final t = loop.value * 2 * math.pi;
    final c = Offset(s / 2, s / 2);

    for (var k = 0; k < _rings; k++) {
      final reveal = _ArtPainter.phase(d, 0.1 + k * 0.07, 0.65 + k * 0.07);
      if (reveal <= 0) continue;
      final path = _ring(c, s, k, t);
      final index = k == 2;
      final alpha = (0.85 - k * 0.12) * (index ? 1 : 0.8);
      canvas.drawPath(
        _ArtPainter.partial(path, reveal),
        _ArtPainter.stroke(
          palette.accent.withValues(alpha: alpha),
          index ? 1.3 : 0.8,
        ),
      );
    }

    // Motes of air drifting a little way along the contours and back.
    final motes = _ArtPainter.phase(d, 0.6, 1);
    if (motes > 0) {
      final dot = Paint()
        ..color = palette.accent.withValues(alpha: 0.7 * motes);
      for (var i = 0; i < 11; i++) {
        final k = 1 + i % (_rings - 1);
        final theta = i * 2.39996 + 0.35 * math.sin(t + i * 1.7);
        canvas.drawCircle(_ringPoint(c, s, k, t, theta), 1.6 - k * 0.12, dot);
      }
    }

    _ArtPainter.fHole(
      canvas,
      c,
      s * 0.58,
      palette.ink,
      _ArtPainter.phase(d, 0, 0.7),
    );
  }

  Path _ring(Offset c, double s, int k, double t) {
    const steps = 120;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final p = _ringPoint(c, s, k, t, -math.pi / 2 + 2 * math.pi * i / steps);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  Offset _ringPoint(Offset c, double s, int k, double t, double theta) {
    final rx = s * (0.14 + k * 0.054);
    final ry = s * (0.35 + k * 0.027);
    final a = 0.012 + k * 0.004;
    final wobble =
        a *
        (0.6 * math.sin(3 * theta + k * 0.9 + t) +
            0.4 * math.sin(5 * theta - k * 1.3 - t));
    // Each ring swells a moment after the one inside it: a slow outward breath.
    final breath = 1 + 0.018 * math.sin(t - k * 0.55);
    final r = (1 + wobble) * breath;
    return c + Offset(rx * math.cos(theta) * r, ry * math.sin(theta) * r);
  }
}

/// Page 2: a knock. The trace records along the bottom; when the pen reaches
/// the impact, a ripple spreads out from the f-hole.
class _ImpactPainter extends _ArtPainter {
  _ImpactPainter(super.draw, super.loop, super.palette);

  static const _x0 = 0.08, _x1 = 0.92, _xi = 0.4, _penEnd = 0.82;
  static const _hit = _penEnd * (_xi - _x0) / (_x1 - _x0);

  @override
  void paintSquare(Canvas canvas, double s) {
    final d = draw.value;
    final t = loop.value;
    final c = Offset(s / 2, s * 0.4);
    final baseY = s * 0.9;

    // Ripple: three rings, the later ones fainter, all easing out and fading.
    for (var i = 0; i < 3; i++) {
      final p = ((t - _hit - i * 0.07) / 0.55).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final r = s * (0.06 + 0.32 * Curves.easeOutCubic.transform(p));
      final fade = math.pow(1 - p, 1.6).toDouble() * (1 - i * 0.28);
      canvas.drawCircle(
        c,
        r,
        _ArtPainter.stroke(
          palette.accent.withValues(alpha: 0.9 * fade),
          0.6 + 0.9 * (1 - p),
        ),
      );
    }

    // Quiet guide circle the ripple rides out to.
    final guide = _ArtPainter.phase(d, 0.2, 0.9);
    if (guide > 0) {
      final path = Path()
        ..addArc(
          Rect.fromCircle(center: c, radius: s * 0.34),
          -math.pi / 2,
          2 * math.pi,
        );
      canvas.drawPath(
        _ArtPainter.partial(path, guide),
        _ArtPainter.stroke(palette.hairline, 0.8),
      );
    }

    _ArtPainter.fHole(
      canvas,
      c,
      s * 0.5,
      palette.ink,
      _ArtPainter.phase(d, 0, 0.7),
    );

    // The trace: a hairline baseline with ticks, the recorded part in accent.
    final reveal = _ArtPainter.phase(d, 0.15, 0.8);
    if (reveal <= 0) return;
    final x0 = s * _x0;
    final end = _x0 + (_x1 - _x0) * reveal;
    final x1 = s * end;
    final faint = _ArtPainter.stroke(palette.hairline, 0.8);
    canvas.drawLine(Offset(x0, baseY), Offset(x1, baseY), faint);
    for (var x = _x0; x <= end + 0.001; x += 0.035) {
      final major = ((x - _x0) / 0.035).round() % 4 == 0;
      canvas.drawLine(
        Offset(s * x, baseY + s * 0.025),
        Offset(s * x, baseY + s * (major ? 0.045 : 0.035)),
        faint,
      );
    }

    final pen = (t / _penEnd).clamp(0.0, 1.0);
    final fadeOut = 1 - ((t - _penEnd) / (1 - _penEnd)).clamp(0.0, 1.0);
    final penX = _x0 + (_x1 - _x0) * pen;
    if (d < 1 || penX <= _x0) return;
    final trace = Path()..moveTo(s * _x0, baseY);
    for (var x = _x0; x <= penX; x += 0.002) {
      trace.lineTo(s * x, baseY - s * _displacement(x));
    }
    final ink = palette.accent.withValues(alpha: fadeOut);
    canvas.drawPath(trace, _ArtPainter.stroke(ink, 1.2));
    canvas.drawCircle(
      Offset(s * penX, baseY - s * _displacement(penX)),
      2.4,
      Paint()..color = ink,
    );

    // Once the pen is past the peak, note its size beside it, like a chart
    // annotation.
    const peakX = _xi + 0.32 / 18;
    final note = ((penX - peakX) / 0.06).clamp(0.0, 1.0) * fadeOut;
    if (note <= 0) return;
    final label = TextPainter(
      text: TextSpan(
        text: '2.4 g',
        style: palette.label.copyWith(
          fontSize: s * 0.032,
          letterSpacing: 0.4,
          color: palette.accentInk.withValues(alpha: note),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final tip = Offset(s * peakX, baseY - s * _displacement(peakX));
    label.paint(
      canvas,
      tip - Offset(s * 0.03 + label.width, label.height * 0.5),
    );
    label.dispose();
  }

  /// A sharp knock and its damped ring-down, in fractions of the square.
  static double _displacement(double x) {
    final u = (x - _xi) / 0.32;
    if (u < 0) return 0;
    return 0.11 * math.sin(u * 2 * math.pi * 4.5) * math.exp(-u * 5);
  }
}

/// Page 3: a guilloché seal that stamps in, its rosettes turning slowly.
class _SealPainter extends _ArtPainter {
  _SealPainter(super.draw, super.loop, super.palette);

  @override
  void paintSquare(Canvas canvas, double s) {
    final d = draw.value;
    final t = loop.value;
    final c = Offset(s / 2, s / 2);
    final r = s * 0.44;

    final stamp = Curves.easeOutCubic.transform((d / 0.4).clamp(0.0, 1.0));
    if (stamp <= 0) return;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(1.12 - 0.12 * stamp)
      ..translate(-c.dx, -c.dy);

    final a = palette.accent;
    canvas.drawCircle(c, r, Paint()..color = a.withValues(alpha: 0.07 * stamp));

    // Beaded rim, double rule, and the legend between the rules.
    final bead = Paint()..color = a.withValues(alpha: 0.75 * stamp);
    for (var i = 0; i < 90; i++) {
      final th = 2 * math.pi * i / 90;
      canvas.drawCircle(
        c + Offset(math.cos(th), math.sin(th)) * r * 0.985,
        0.9,
        bead,
      );
    }
    canvas
      ..drawCircle(
        c,
        r * 0.94,
        _ArtPainter.stroke(a.withValues(alpha: stamp), 1.1),
      )
      ..drawCircle(
        c,
        r * 0.775,
        _ArtPainter.stroke(a.withValues(alpha: 0.8 * stamp), 0.8),
      );
    _legendRing(
      canvas,
      c,
      r * 0.857,
      s * 0.031,
      palette.accentInk.withValues(alpha: stamp),
    );

    // Two woven guilloché bands turning in opposite directions, one lobe per loop.
    final weave = _ArtPainter.phase(d, 0.25, 1);
    _guilloche(
      canvas,
      c,
      base: r * 0.56,
      amp: r * 0.13,
      lobes: 10,
      strands: 10,
      turn: 2 * math.pi * t / 10,
      reveal: weave,
      color: a.withValues(alpha: 0.55),
    );
    _guilloche(
      canvas,
      c,
      base: r * 0.33,
      amp: r * 0.06,
      lobes: 6,
      strands: 8,
      turn: -2 * math.pi * t / 6,
      reveal: weave,
      color: a.withValues(alpha: 0.7),
    );

    final boss = _ArtPainter.phase(d, 0.15, 0.6);
    canvas.drawCircle(c, r * 0.2, Paint()..color = a.withValues(alpha: boss));
    _ArtPainter.fHole(
      canvas,
      c,
      r * 0.3,
      palette.ground,
      _ArtPainter.phase(d, 0.35, 0.9),
    );

    canvas.restore();
  }

  void _guilloche(
    Canvas canvas,
    Offset c, {
    required double base,
    required double amp,
    required int lobes,
    required int strands,
    required double turn,
    required double reveal,
    required Color color,
  }) {
    if (reveal <= 0) return;
    final paint = _ArtPainter.stroke(color, 0.55);
    // Revealed by a sweep from twelve o'clock, like a rose engine cutting it.
    canvas.save();
    if (reveal < 1) {
      final reach = base + amp * 2;
      canvas.clipPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..arcTo(
            Rect.fromCircle(center: c, radius: reach),
            -math.pi / 2,
            2 * math.pi * reveal,
            false,
          )
          ..close(),
      );
    }
    const steps = 240;
    for (var k = 0; k < strands; k++) {
      final phase = 2 * math.pi * k / strands;
      final path = Path();
      for (var i = 0; i <= steps; i++) {
        final th = 2 * math.pi * i / steps;
        final rr = base + amp * math.sin(lobes * th + phase);
        final p = c + Offset(math.cos(th + turn), math.sin(th + turn)) * rr;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  /// Seal legend: one line over the top reading clockwise, one under the
  /// bottom reading upright, with a lozenge at each side between them.
  void _legendRing(
    Canvas canvas,
    Offset c,
    double radius,
    double fontSize,
    Color color,
  ) {
    final style = palette.label.copyWith(
      fontSize: fontSize,
      color: color,
      letterSpacing: 0,
      height: 1,
    );
    _arcText(canvas, c, radius, 'SIGNED CONDITION RECORD', style, top: true);
    _arcText(canvas, c, radius, 'AELOS', style, top: false);

    final lozenge = Paint()..color = color;
    for (final side in [-1.0, 1.0]) {
      final p = c + Offset(side * radius, 0);
      final h = fontSize * 0.32;
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - h)
          ..lineTo(p.dx + h * 0.7, p.dy)
          ..lineTo(p.dx, p.dy + h)
          ..lineTo(p.dx - h * 0.7, p.dy)
          ..close(),
        lozenge,
      );
    }
  }

  void _arcText(
    Canvas canvas,
    Offset c,
    double radius,
    String text,
    TextStyle style, {
    required bool top,
  }) {
    final tracking = style.fontSize! * 0.42;
    final glyphs = [
      for (final ch in text.split(''))
        TextPainter(
          text: TextSpan(text: ch, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final length =
        glyphs.fold<double>(0, (sum, g) => sum + g.width) +
        tracking * (glyphs.length - 1);
    // Top runs clockwise from the left; bottom runs anticlockwise so its
    // letters stand upright.
    final dir = top ? 1.0 : -1.0;
    final middle = top ? -math.pi / 2 : math.pi / 2;
    var along = -length / 2;
    for (final g in glyphs) {
      final angle = middle + dir * (along + g.width / 2) / radius;
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(angle + dir * math.pi / 2)
        ..translate(0, -dir * radius);
      g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
      canvas.restore();
      along += g.width + tracking;
      g.dispose();
    }
  }
}
