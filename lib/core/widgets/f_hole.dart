import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The violin f-hole, the app's recurring motif: watermark behind headings,
/// pairing animation, empty states. Width:height is 1:4.
class FHole extends StatelessWidget {
  const FHole({super.key, required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(height / 4, height),
        painter: FHolePainter(color),
      );
}

class FHolePainter extends CustomPainter {
  const FHolePainter(this.color, {this.progress = 1});

  final Color color;

  /// 0–1: how much of the stem is drawn, top eye first. Used to draw the
  /// motif in during pairing; eyes appear at the start and end.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    // Stem centreline: a long S from the upper-right eye to the lower-left eye.
    Offset at(double t) {
      const p0 = Offset(0.68, 0.10), p1 = Offset(0.08, 0.30);
      const p2 = Offset(0.94, 0.70), p3 = Offset(0.32, 0.90);
      final u = 1 - t;
      final p = p0 * (u * u * u) +
          p1 * (3 * u * u * t) +
          p2 * (3 * u * t * t) +
          p3 * (t * t * t);
      return Offset(p.dx * w, p.dy * h);
    }

    // Narrow at the eyes and at the waist, with a fuller wing above and a
    // slightly larger one below, like a carved f-hole.
    double halfWidth(double t) {
      final wing = t < 0.5 ? 0.085 : 0.105;
      return w * (0.03 + wing * math.pow(math.sin(2 * math.pi * t).abs(), 0.85));
    }

    const steps = 64;
    final end = progress.clamp(0.0, 1.0);
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = end * i / steps;
      final p = at(t);
      final d = at(math.min(t + 0.001, 1)) - at(math.max(t - 0.001, 0));
      final n = Offset(-d.dy, d.dx) / d.distance;
      left.add(p + n * halfWidth(t));
      right.add(p - n * halfWidth(t));
    }
    if (end > 0) {
      canvas.drawPath(
        Path()
          ..addPolygon([...left, ...right.reversed], true),
        paint,
      );
    }

    canvas.drawCircle(Offset(0.74 * w, 0.075 * h), 0.14 * w, paint);
    if (end >= 1) {
      canvas.drawCircle(Offset(0.26 * w, 0.925 * h), 0.16 * w, paint);

      // The two nicks at the waist, where the luthier marks the bridge line.
      final waist = at(0.5);
      final nick = Paint()
        ..color = color
        ..strokeWidth = w * 0.04
        ..strokeCap = StrokeCap.round;
      final reach = halfWidth(0.5) + w * 0.14;
      canvas
        ..drawLine(waist - Offset(reach, 0), waist - Offset(halfWidth(0.5), 0), nick)
        ..drawLine(waist + Offset(halfWidth(0.5), 0), waist + Offset(reach, 0), nick);
    }
  }

  @override
  bool shouldRepaint(FHolePainter old) =>
      old.color != color || old.progress != progress;
}
