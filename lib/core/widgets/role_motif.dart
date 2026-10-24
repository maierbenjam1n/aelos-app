import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/account.dart';
import '../theme/aelos_colors.dart';
import '../theme/tokens.dart';
import 'f_hole.dart';

/// Line illustration for a way of using Aelos, inside a hairline medallion:
/// one f-hole (owner), a workshop tag (renter), a family of three f-holes
/// (luthier's fleet). Draws itself in when [animate] is true.
class RoleMotif extends StatelessWidget {
  const RoleMotif(
    this.role, {
    super.key,
    required this.size,
    this.animate = false,
    this.delay = Duration.zero,
  });

  final AccountRole role;
  final double size;
  final bool animate;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    Widget paint(double progress) => CustomPaint(
          size: Size.square(size),
          painter: RoleMotifPainter(
            role,
            ink: colors.text,
            accent: colors.accent,
            progress: progress,
          ),
        );
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      return RepaintBoundary(child: paint(1));
    }
    return RepaintBoundary(child: _DrawIn(delay: delay, builder: paint));
  }
}

class _DrawIn extends StatefulWidget {
  const _DrawIn({required this.delay, required this.builder});

  final Duration delay;
  final Widget Function(double progress) builder;

  @override
  State<_DrawIn> createState() => _DrawInState();
}

class _DrawInState extends State<_DrawIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.chartDraw,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => widget.builder(_controller.value),
      );
}

class RoleMotifPainter extends CustomPainter {
  const RoleMotifPainter(
    this.role, {
    required this.ink,
    required this.accent,
    this.progress = 1,
  });

  final AccountRole role;
  final Color ink;
  final Color accent;

  /// 0–1: the medallion traces round first, then the motif draws in.
  final double progress;

  static double _phase(double p, double start, double end) => Curves
      .easeInOutCubic
      .transform(((p - start) / (end - start)).clamp(0.0, 1.0));

  static Path _partial(Path path, double fraction) {
    if (fraction >= 1) return path;
    final out = Path();
    if (fraction <= 0) return out;
    for (final m in path.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * fraction), Offset.zero);
    }
    return out;
  }

  Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color
    ..isAntiAlias = true;

  static void _fHole(
    Canvas canvas,
    Offset centre,
    double height,
    Color color,
    double progress,
  ) {
    if (progress <= 0) return;
    final size = Size(height / 4, height);
    canvas
      ..save()
      ..translate(centre.dx - size.width / 2, centre.dy - size.height / 2);
    FHolePainter(color, progress: progress).paint(canvas, size);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    canvas
      ..save()
      ..translate((size.width - s) / 2, (size.height - s) / 2);
    // Hairlines stay hairlines at any size, but thicken a touch when large.
    final hair = math.max(0.8, s * 0.012);
    final medallion = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s * 0.47),
        -math.pi / 2,
        2 * math.pi,
      );
    canvas.drawPath(
      _partial(medallion, _phase(progress, 0, 0.55)),
      _stroke(accent.withValues(alpha: 0.55), hair),
    );

    switch (role) {
      case AccountRole.owner:
        _paintOwner(canvas, s, hair);
      case AccountRole.renter:
        _paintRenter(canvas, s, hair);
      case AccountRole.luthier:
        _paintLuthier(canvas, s, hair);
    }
    canvas.restore();
  }

  void _paintOwner(Canvas canvas, double s, double hair) {
    final c = Offset(s / 2, s / 2);
    final ring = Path()
      ..addArc(
        Rect.fromCircle(center: c, radius: s * 0.39),
        math.pi / 2,
        2 * math.pi,
      );
    canvas.drawPath(
      _partial(ring, _phase(progress, 0.2, 0.75)),
      _stroke(accent.withValues(alpha: 0.28), hair * 0.8),
    );
    _fHole(canvas, c, s * 0.64, ink, _phase(progress, 0.15, 1));
  }

  void _paintRenter(Canvas canvas, double s, double hair) {
    final c = Offset(s * 0.5, s * 0.55);
    final w = s * 0.34, h = s * 0.48, ch = s * 0.09, r = s * 0.035;
    final l = -w / 2, t = -h / 2, rt = w / 2, b = h / 2;
    final tag = Path()
      ..moveTo(0, t)
      ..lineTo(rt - ch, t)
      ..lineTo(rt, t + ch)
      ..lineTo(rt, b - r)
      ..quadraticBezierTo(rt, b, rt - r, b)
      ..lineTo(l + r, b)
      ..quadraticBezierTo(l, b, l, b - r)
      ..lineTo(l, t + ch)
      ..lineTo(l + ch, t)
      ..close();
    final eye = Offset(0, t + s * 0.075);

    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(-0.32);
    canvas.drawPath(
      _partial(tag, _phase(progress, 0.1, 0.7)),
      _stroke(ink, hair * 1.25),
    );
    final eyeIn = _phase(progress, 0.45, 0.7);
    if (eyeIn > 0) {
      canvas.drawCircle(
        eye,
        s * 0.028 * eyeIn,
        _stroke(ink, hair),
      );
    }
    // The tie: from the eyelet, a loop up and out, the way a workshop tag
    // hangs from a scroll.
    final tie = Path()
      ..moveTo(eye.dx, eye.dy)
      ..cubicTo(
        eye.dx - s * 0.02,
        eye.dy - s * 0.18,
        eye.dx + s * 0.2,
        eye.dy - s * 0.2,
        eye.dx + s * 0.16,
        eye.dy - s * 0.07,
      )
      ..cubicTo(
        eye.dx + s * 0.13,
        eye.dy + s * 0.01,
        eye.dx + s * 0.04,
        eye.dy - s * 0.02,
        eye.dx + s * 0.11,
        eye.dy - s * 0.15,
      );
    canvas.drawPath(
      _partial(tie, _phase(progress, 0.5, 1)),
      _stroke(accent, hair * 1.1),
    );
    _fHole(canvas, Offset(0, s * 0.06), s * 0.28, ink, _phase(progress, 0.4, 1));
    canvas.restore();
  }

  void _paintLuthier(Canvas canvas, double s, double hair) {
    // Violin, viola, cello: one family of f-holes standing on one line.
    final base = s * 0.77;
    final heights = [s * 0.38, s * 0.47, s * 0.56];
    final xs = [s * 0.3, s * 0.5, s * 0.7];
    for (var i = 0; i < 3; i++) {
      _fHole(
        canvas,
        Offset(xs[i], base - heights[i] / 2),
        heights[i],
        ink,
        _phase(progress, 0.15 + i * 0.12, 0.75 + i * 0.08),
      );
    }
    final line = _phase(progress, 0.25, 0.8);
    if (line > 0) {
      final half = s * 0.27 * line;
      canvas.drawLine(
        Offset(s / 2 - half, base + s * 0.05),
        Offset(s / 2 + half, base + s * 0.05),
        _stroke(accent, hair),
      );
    }
  }

  @override
  bool shouldRepaint(RoleMotifPainter old) =>
      old.role != role ||
      old.ink != ink ||
      old.accent != accent ||
      old.progress != progress;
}
