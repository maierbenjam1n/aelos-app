import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/f_hole.dart';
import '../../domain/models/event_report.dart';
import '../../domain/models/instrument.dart';

/// A luthier's line drawing of an instrument as seen from one [PhotoAngle]:
/// the outline to line the photo up with. [progress] draws it in, outline
/// first, then the fittings.
///
/// Geometry is in body lengths: the body runs from y = 0 (neck end) to
/// y = 1 (end button), centred on x = 0. Each view fits its own bounds.
class InstrumentDrawingPainter extends CustomPainter {
  InstrumentDrawingPainter({
    required this.type,
    required this.angle,
    required this.ink,
    required this.detail,
    this.progress = const AlwaysStoppedAnimation(1),
  }) : super(repaint: progress);

  final InstrumentType type;
  final PhotoAngle angle;

  /// Outline and f-holes.
  final Color ink;

  /// Purfling, strings, wood figure.
  final Color detail;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final b = _Build.of(type);
    final p = progress.value;
    if (p <= 0 || size.isEmpty) return;
    if (angle == PhotoAngle.detail) return _loupe(canvas, size, b, p);
    final view = switch (angle) {
      PhotoAngle.front || PhotoAngle.detail => _View.front,
      PhotoAngle.back => _View.back,
      PhotoAngle.bassSide => _View.bassSide,
      PhotoAngle.trebleSide => _View.trebleSide,
      PhotoAngle.scroll => _View.bassSide,
    };
    final bounds = switch (angle) {
      PhotoAngle.scroll => b.headBounds,
      _ => view == _View.front || view == _View.back ? b.frontBounds : b.sideBounds,
    };
    final scale = math.min(size.width / bounds.width, size.height / bounds.height);
    final pen = _Pen(scale, ink, detail);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      size.width / 2 - bounds.center.dx * scale * (view == _View.trebleSide ? -1 : 1),
      size.height / 2 - bounds.center.dy * scale,
    );
    canvas.scale(view == _View.trebleSide ? -scale : scale, scale);
    switch (view) {
      case _View.front:
        _front(canvas, b, p, pen);
      case _View.back:
        _back(canvas, b, p, pen);
      case _View.bassSide || _View.trebleSide:
        _side(canvas, b, p, pen);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(InstrumentDrawingPainter old) =>
      old.type != type ||
      old.angle != angle ||
      old.ink != ink ||
      old.detail != detail ||
      old.progress != progress;

  /// Close-up: the upper corner and C-bout under a loupe, with a reticle.
  void _loupe(Canvas canvas, Size size, _Build b, double p) {
    final c = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.4;
    const region = Rect.fromLTWH(-0.04, 0.27, 0.4, 0.4);
    final scale = radius * 2 / region.width;
    final pen = _Pen(scale, ink, detail);
    final lens = _phase(p, 0, 0.5);

    canvas
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: radius)))
      ..translate(c.dx - region.center.dx * scale, c.dy - region.center.dy * scale)
      ..scale(scale);
    _front(canvas, b, Curves.easeOut.transform(((p - 0.2) / 0.8).clamp(0.0, 1.0)), pen);
    canvas.restore();

    Paint line(Color color, double width, double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: color.a * alpha);
    final rim = Rect.fromCircle(center: c, radius: radius);
    canvas
      ..drawArc(rim, -math.pi / 2, 2 * math.pi * lens, false, line(ink, 1.3, 1))
      ..drawCircle(c, radius + 7, line(detail, 0.7, lens * 0.7));
    for (var i = 0; i < 72; i++) {
      final th = 2 * math.pi * i / 72;
      final major = i % 6 == 0;
      final dir = Offset(math.cos(th), math.sin(th));
      canvas.drawLine(
        c + dir * (radius + 11),
        c + dir * (radius + (major ? 19 : 14)),
        line(major ? ink : detail, major ? 1 : 0.7, _phase(p, 0.3 + i / 72 * 0.4, 0.45 + i / 72 * 0.4)),
      );
    }
  }

  // ── Front ──────────────────────────────────────────────────────────────

  void _front(Canvas canvas, _Build b, double p, _Pen pen) {
    final outline = _phase(p, 0, 0.6);
    final fittings = _phase(p, 0.25, 0.8);
    final late = _phase(p, 0.55, 1);

    _drawOutline(canvas, b, outline, pen);
    canvas.drawPath(_purfling(b), pen.stroke(pen.detail, 0.7, late * 0.8));
    _endpin(canvas, b, late, pen, front: true);

    // Fingerboard, nut, pegbox, pegs and scroll seen from the front.
    final w = b.neckW;
    final board = Path()
      ..moveTo(-w, -b.neck)
      ..lineTo(w, -b.neck)
      ..lineTo(w * 1.7, b.boardEnd - 0.012)
      ..quadraticBezierTo(0, b.boardEnd + 0.008, -w * 1.7, b.boardEnd - 0.012)
      ..close();
    canvas.drawPath(_partial(board, fittings), pen.stroke(pen.ink, 1, 0.9));
    _head(canvas, b, fittings, pen);

    // f-holes: the lower eyes sit wider apart than the upper ones.
    final fHeight = b.fHole;
    for (final side in [-1.0, 1.0]) {
      canvas
        ..save()
        ..translate(side * b.fHoleX, b.bridgeY)
        ..scale(-side, 1)
        ..translate(-fHeight / 8, -fHeight / 2);
      FHolePainter(pen.ink.withValues(alpha: 0.85), progress: _phase(p, 0.35, 0.9))
          .paint(canvas, Size(fHeight / 4, fHeight));
      canvas.restore();
    }

    if (late <= 0) return;
    final strings = pen.stroke(pen.detail, 0.6, late * 0.9);
    final bridge = Path()
      ..moveTo(-0.072, b.bridgeY + 0.004)
      ..quadraticBezierTo(0, b.bridgeY - 0.022, 0.072, b.bridgeY + 0.004)
      ..lineTo(0.06, b.bridgeY + 0.012)
      ..quadraticBezierTo(0, b.bridgeY - 0.006, -0.06, b.bridgeY + 0.012)
      ..close();
    canvas.drawPath(bridge, pen.stroke(pen.ink, 0.9, late));

    final tailTop = b.bridgeY + 0.15;
    final tail = Path()
      ..moveTo(-0.048, tailTop + 0.012)
      ..quadraticBezierTo(0, tailTop - 0.014, 0.048, tailTop + 0.012)
      ..cubicTo(0.046, 0.8, 0.03, 0.9, 0.024, 0.952)
      ..quadraticBezierTo(0, 0.962, -0.024, 0.952)
      ..cubicTo(-0.03, 0.9, -0.046, 0.8, -0.048, tailTop + 0.012)
      ..close();
    canvas
      ..drawPath(tail, pen.stroke(pen.ink, 0.9, late))
      ..drawLine(const Offset(-0.03, 0.988), const Offset(0.03, 0.988), pen.stroke(pen.ink, 0.9, late));

    for (var i = 0; i < 4; i++) {
      final k = (i - 1.5) / 1.5;
      final nut = Offset(k * w * 0.72, -b.neck);
      final top = Offset(k * 0.05, b.bridgeY - 0.012 + 0.006 * k.abs());
      final end = Offset(k * 0.03, tailTop + 0.004);
      canvas.drawPath(
        Path()
          ..moveTo(nut.dx, nut.dy)
          ..lineTo(top.dx, top.dy)
          ..lineTo(end.dx, end.dy),
        strings,
      );
    }

    if (b.chinrest) {
      canvas
        ..save()
        ..translate(-0.118, 0.862)
        ..rotate(-0.28);
      final rest = Rect.fromCenter(center: Offset.zero, width: 0.17, height: 0.1);
      canvas
        ..drawOval(rest, pen.stroke(pen.ink, 0.9, late * 0.8))
        ..drawOval(
          Rect.fromCenter(center: const Offset(0.006, -0.004), width: 0.11, height: 0.055),
          pen.stroke(pen.detail, 0.6, late * 0.7),
        )
        ..restore();
    }
  }

  // ── Back ───────────────────────────────────────────────────────────────

  void _back(Canvas canvas, _Build b, double p, _Pen pen) {
    final outline = _phase(p, 0, 0.6);
    final fittings = _phase(p, 0.25, 0.8);
    final late = _phase(p, 0.55, 1);

    // Flamed maple, faintly, inside the outline.
    if (late > 0) {
      canvas
        ..save()
        ..clipPath(_outlinePath(b));
      final flame = pen.stroke(pen.detail, 0.6, late * 0.45);
      for (var i = -2; i < 12; i++) {
        final y = 0.04 + i * 0.085;
        canvas.drawPath(
          Path()
            ..moveTo(-0.32, y + 0.07)
            ..cubicTo(-0.12, y + 0.02, 0.1, y - 0.02, 0.32, y - 0.075),
          flame,
        );
      }
      canvas
        ..restore()
        ..drawLine(const Offset(0, 0.035), const Offset(0, 0.975), pen.stroke(pen.detail, 0.6, late * 0.6));
    }

    _drawOutline(canvas, b, outline, pen);
    canvas.drawPath(_purfling(b), pen.stroke(pen.detail, 0.7, late * 0.8));
    _endpin(canvas, b, late, pen, front: false);

    // Neck from behind, with the button where it meets the back.
    final w = b.neckW;
    final neck = Path()
      ..moveTo(-w * 0.95, -b.neck)
      ..cubicTo(-w * 1.05, -b.neck * 0.5, -w * 1.15, -0.06, -w * 1.5, -0.012)
      ..moveTo(w * 0.95, -b.neck)
      ..cubicTo(w * 1.05, -b.neck * 0.5, w * 1.15, -0.06, w * 1.5, -0.012)
      ..moveTo(-w * 1.25, 0.004)
      ..arcToPoint(Offset(w * 1.25, 0.004), radius: Radius.circular(w * 1.25), clockwise: false);
    canvas.drawPath(_partial(neck, fittings), pen.stroke(pen.ink, 1, 0.9));
    _head(canvas, b, fittings, pen);
  }

  // ── Side (bass side; the treble side is this, mirrored) ────────────────

  void _side(Canvas canvas, _Build b, double p, _Pen pen) {
    final outline = _phase(p, 0, 0.6);
    final fittings = _phase(p, 0.25, 0.85);
    final late = _phase(p, 0.55, 1);
    final r = b.ribs / 2;
    final arch = b.arch;
    final g = _SideGeometry(b);

    // Plates: the top (to the right) and the back, arched over the ribs.
    final body = Path()
      ..moveTo(r, 0.004)
      ..cubicTo(r + arch * 1.33, 0.1, r + arch * 1.33, 0.9, r, 0.996)
      ..moveTo(-r, 0.004)
      ..cubicTo(-r - arch * 1.33, 0.1, -r - arch * 1.33, 0.9, -r, 0.996);
    final ribs = Path()
      ..moveTo(-r, 0.004)
      ..quadraticBezierTo(0, -0.01, r, 0.004)
      ..lineTo(r, 0.996)
      ..quadraticBezierTo(0, 1.01, -r, 0.996)
      ..close();
    canvas
      ..drawPath(_partial(ribs, outline), pen.stroke(pen.ink, 1.2, 1))
      ..drawPath(_partial(body, outline), pen.stroke(pen.ink, 1.2, 1));

    if (late > 0) {
      // Rib joints at the corner blocks, and the edge overhang.
      final joint = pen.stroke(pen.detail, 0.7, late * 0.9);
      for (final y in [0.34, 0.61]) {
        canvas.drawLine(Offset(-r, y), Offset(r, y), joint);
      }
    }
    _endpin(canvas, b, late, pen, front: false);

    // Neck, fingerboard and head in profile.
    final neck = Path()
      ..moveTo(g.nut.dx - g.boardDepth, -b.neck)
      ..lineTo(g.heelTop.dx, -0.004)
      ..moveTo(g.nut.dx - g.neckDepth, -b.neck + 0.02)
      ..lineTo(-r * 0.25, -0.05)
      ..quadraticBezierTo(-r * 0.85, -0.035, -r - 0.004, 0.004);
    final board = Path()
      ..moveTo(g.nut.dx, -b.neck)
      ..lineTo(g.boardEndTop.dx, b.boardEnd)
      ..lineTo(g.boardEndTop.dx - g.boardDepth * 1.4, b.boardEnd)
      ..lineTo(g.nut.dx - g.boardDepth, -b.neck)
      ..close();
    canvas
      ..drawPath(_partial(neck, fittings), pen.stroke(pen.ink, 1, 1))
      ..drawPath(_partial(board, fittings), pen.stroke(pen.ink, 1, 1));
    _sideHead(canvas, b, g, fittings, late, pen);

    if (late <= 0) return;
    final bridgeFoot = Offset(r + arch * 0.98, b.bridgeY);
    final bridge = Path()
      ..moveTo(bridgeFoot.dx, b.bridgeY - 0.012)
      ..lineTo(g.bridgeTop.dx, b.bridgeY - 0.003)
      ..lineTo(g.bridgeTop.dx, b.bridgeY + 0.004)
      ..lineTo(bridgeFoot.dx, b.bridgeY + 0.014);
    final tailTop = Offset(r + arch * 0.9 + 0.02, b.bridgeY + 0.15);
    final tailEnd = Offset(r + 0.012, 0.955);
    final tail = Path()
      ..moveTo(tailTop.dx, tailTop.dy)
      ..lineTo(tailEnd.dx, tailEnd.dy)
      ..lineTo(tailEnd.dx - 0.008, tailEnd.dy)
      ..lineTo(tailTop.dx - 0.014, tailTop.dy + 0.004)
      ..close();
    canvas
      ..drawPath(bridge, pen.stroke(pen.ink, 0.9, late))
      ..drawPath(tail, pen.stroke(pen.ink, 0.9, late))
      ..drawPath(
        Path()
          ..moveTo(g.nut.dx + 0.004, -b.neck)
          ..lineTo(g.bridgeTop.dx, b.bridgeY - 0.001)
          ..lineTo(tailTop.dx, tailTop.dy),
        pen.stroke(pen.detail, 0.6, late),
      );
  }

  /// Pegbox, pegs and scroll from the side, with the scroll's volute.
  void _sideHead(Canvas canvas, _Build b, _SideGeometry g, double fittings, double late, _Pen pen) {
    final s = g.scroll;
    final big = g.scrollR;
    final front = s + Offset(math.cos(0.5), math.sin(0.5)) * big;
    final back = s + Offset(math.cos(2.35), math.sin(2.35)) * big;
    final head = Path()
      ..moveTo(g.nut.dx, -b.neck)
      ..cubicTo(g.nut.dx + 0.004, -b.neck - b.head * 0.25, front.dx + 0.01, front.dy + big * 0.6, front.dx, front.dy)
      ..arcTo(Rect.fromCircle(center: s, radius: big), 0.5, -(2 * math.pi - (2.35 - 0.5)), false)
      ..cubicTo(
        back.dx + 0.004,
        back.dy + big * 0.5,
        g.nut.dx - g.neckDepth,
        -b.neck - b.head * 0.25,
        g.nut.dx - g.neckDepth,
        -b.neck + 0.02,
      );
    canvas.drawPath(_partial(head, fittings), pen.stroke(pen.ink, 1, 1));

    // The volute: two log spirals winding into the eye.
    if (late <= 0) return;
    const turns = 2.2;
    final k = math.log(1 / 0.15) / (turns * 2 * math.pi);
    Path spiral(double startR, double startPhi) {
      final path = Path();
      const steps = 200;
      for (var i = 0; i <= steps; i++) {
        final phi = startPhi + (turns * 2 * math.pi - startPhi) * i / steps;
        final rr = startR * math.exp(-k * phi) * (1 - 0.06 * math.min(phi, 1));
        final th = 2.35 - phi;
        final pt = s + Offset(math.cos(th), math.sin(th)) * rr;
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      return path;
    }

    canvas
      ..drawPath(_partial(spiral(big, 0), late), pen.stroke(pen.ink, 1, 1))
      ..drawPath(_partial(spiral(big * 0.8, 0.9), late), pen.stroke(pen.detail, 0.7, 1))
      ..drawCircle(s, big * 0.1, Paint()..color = pen.ink.withValues(alpha: late));

    // Peg heads facing us, alternating with the far-side pegs' ends.
    for (var i = 0; i < b.pegs; i++) {
      final t = (i + 0.7) / (b.pegs + 0.5);
      final along = Offset.lerp(
        Offset(g.nut.dx - g.neckDepth * 0.5, -b.neck - 0.01),
        Offset(s.dx + big * 0.15, s.dy + big * 1.05),
        t,
      )!;
      if (i.isEven) {
        canvas
          ..save()
          ..translate(along.dx, along.dy)
          ..rotate(-0.5)
          ..drawOval(
            Rect.fromCenter(center: Offset.zero, width: b.pegR * 1.4, height: b.pegR * 2.1),
            pen.stroke(pen.ink, 0.9, late),
          )
          ..drawCircle(Offset.zero, b.pegR * 0.38, pen.stroke(pen.detail, 0.7, late))
          ..drawCircle(Offset.zero, b.pegR * 0.12, Paint()..color = pen.ink.withValues(alpha: late))
          ..restore();
      } else {
        canvas.drawCircle(along, b.pegR * 0.22, Paint()..color = pen.detail.withValues(alpha: late));
      }
    }
  }

  // ── Shared parts ───────────────────────────────────────────────────────

  /// Pegbox, pegs and scroll from the front or back.
  void _head(Canvas canvas, _Build b, double fittings, _Pen pen) {
    if (fittings <= 0) return;
    final w = b.neckW;
    final boxTop = -b.neck - b.head * 0.62;
    final scrollC = Offset(0, -b.neck - b.head * 0.8);
    final scrollH = b.head * 0.2;
    final head = Path()
      ..moveTo(-w * 0.95, -b.neck)
      ..lineTo(-w * 0.78, boxTop)
      ..moveTo(w * 0.95, -b.neck)
      ..lineTo(w * 0.78, boxTop)
      ..addOval(Rect.fromCenter(center: scrollC, width: w * 2.3, height: scrollH * 2))
      ..addOval(Rect.fromCenter(center: scrollC + Offset(0, scrollH * 0.12), width: w * 1.2, height: scrollH * 1.3))
      ..moveTo(0, scrollC.dy - scrollH)
      ..lineTo(0, scrollC.dy + scrollH);
    canvas.drawPath(_partial(head, fittings), pen.stroke(pen.ink, 1, 0.9));

    final peg = pen.stroke(pen.ink, 0.9, fittings);
    for (var i = 0; i < b.pegs; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final y = -b.neck - (boxTop + b.neck).abs() * (i + 0.7) / (b.pegs + 0.4);
      final x0 = side * w * 0.88;
      final x1 = side * (w + b.pegR * 1.6);
      canvas
        ..drawLine(Offset(x0, y), Offset(x1, y), peg)
        ..drawLine(Offset(x1, y - b.pegR * 0.4), Offset(x1, y + b.pegR * 0.4), peg)
        ..drawOval(
          Rect.fromCenter(
            center: Offset(x1 + side * b.pegR * 1.15, y),
            width: b.pegR * 2.2,
            height: b.pegR * 1.4,
          ),
          peg,
        );
    }
  }

  void _endpin(Canvas canvas, _Build b, double late, _Pen pen, {required bool front}) {
    if (late <= 0) return;
    final paint = pen.stroke(pen.ink, 1, late);
    if (b.endpin == 0) {
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 1.008), width: 0.03, height: 0.016), paint);
      return;
    }
    canvas
      ..drawRRect(
        RRect.fromLTRBR(-0.018, 0.996, 0.018, 1.03, const Radius.circular(0.006)),
        paint,
      )
      ..drawLine(const Offset(0, 1.03), Offset(0, 1 + b.endpin * late), paint)
      ..drawCircle(Offset(0, 1 + b.endpin * late), 0.006, Paint()..color = pen.ink.withValues(alpha: late));
  }

  void _drawOutline(Canvas canvas, _Build b, double t, _Pen pen) {
    final paint = pen.stroke(pen.ink, 1.25, 1);
    final (right, left) = _halves(b);
    canvas
      ..drawPath(_partial(right, t), paint)
      ..drawPath(_partial(left, t), paint);
  }

  static double _phase(double p, double start, double end) =>
      Curves.easeInOutCubic.transform(((p - start) / (end - start)).clamp(0.0, 1.0));

  static Path _partial(Path path, double fraction) {
    if (fraction >= 1) return path;
    final out = Path();
    if (fraction <= 0) return out;
    for (final m in path.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * fraction), Offset.zero);
    }
    return out;
  }

  static final _outlineCache = <_Build, Path>{};
  static final _purflingCache = <_Build, Path>{};

  static Path _outlinePath(_Build b) => _outlineCache.putIfAbsent(b, () {
        final segs = b.rightHalf;
        final path = Path()..moveTo(0, 0);
        for (final (c1, c2, p) in segs) {
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p.dx, p.dy);
        }
        final starts = [Offset.zero, for (final s in segs) s.$3];
        for (var i = segs.length - 1; i >= 0; i--) {
          final (c1, c2, _) = segs[i];
          path.cubicTo(-c2.dx, c2.dy, -c1.dx, c1.dy, -starts[i].dx, starts[i].dy);
        }
        return path..close();
      });

  /// Right and left halves, each from the neck down to the end button, so
  /// the outline draws in symmetrically.
  static (Path, Path) _halves(_Build b) {
    final right = Path()..moveTo(0, 0);
    final left = Path()..moveTo(0, 0);
    for (final (c1, c2, p) in b.rightHalf) {
      right.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p.dx, p.dy);
      left.cubicTo(-c1.dx, c1.dy, -c2.dx, c2.dy, -p.dx, p.dy);
    }
    return (right, left);
  }

  /// The outline inset by the purfling margin, following its normals.
  static Path _purfling(_Build b) => _purflingCache.putIfAbsent(b, () {
        const inset = 0.012;
        final out = Path();
        for (final m in _outlinePath(b).computeMetrics()) {
          const steps = 360;
          for (var i = 0; i <= steps; i++) {
            final t = m.getTangentForOffset(m.length * i / steps)!;
            final n = Offset(-t.vector.dy, t.vector.dx);
            final pt = t.position + n * inset;
            i == 0 ? out.moveTo(pt.dx, pt.dy) : out.lineTo(pt.dx, pt.dy);
          }
        }
        return out..close();
      });
}

enum _View { front, back, bassSide, trebleSide }

/// Stroke widths are given in screen pixels and converted to body units.
class _Pen {
  const _Pen(this.scale, this.ink, this.detail);

  final double scale;
  final Color ink;
  final Color detail;

  Paint stroke(Color color, double px, double alpha) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = px / scale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color.withValues(alpha: color.a * alpha.clamp(0.0, 1.0))
    ..isAntiAlias = true;
}

/// Proportions per family, from typical measurements (violin body 356 mm,
/// cello 755 mm, bass about 1100 mm), lightly stylised so the families read
/// apart at a glance: deeper ribs, a longer neck and an endpin for the
/// low strings, sloped shoulders for the bass.
final class _Build {
  const _Build({
    required this.neck,
    required this.head,
    required this.ribs,
    required this.arch,
    required this.neckW,
    required this.neckDepth,
    required this.boardEnd,
    required this.bridgeY,
    required this.bridgeH,
    required this.fHole,
    required this.fHoleX,
    required this.pegR,
    this.endpin = 0,
    this.sloped = false,
    this.chinrest = false,
  });

  static const violin = _Build(
    neck: 0.37,
    head: 0.29,
    ribs: 0.085,
    arch: 0.045,
    neckW: 0.034,
    neckDepth: 0.06,
    boardEnd: 0.385,
    bridgeY: 0.555,
    bridgeH: 0.095,
    fHole: 0.215,
    fHoleX: 0.102,
    pegR: 0.022,
    chinrest: true,
  );
  static const viola = _Build(
    neck: 0.36,
    head: 0.28,
    ribs: 0.095,
    arch: 0.045,
    neckW: 0.033,
    neckDepth: 0.058,
    boardEnd: 0.38,
    bridgeY: 0.555,
    bridgeH: 0.09,
    fHole: 0.215,
    fHoleX: 0.102,
    pegR: 0.021,
    chinrest: true,
  );
  static const cello = _Build(
    neck: 0.43,
    head: 0.3,
    ribs: 0.16,
    arch: 0.04,
    neckW: 0.034,
    neckDepth: 0.055,
    boardEnd: 0.41,
    bridgeY: 0.565,
    bridgeH: 0.12,
    fHole: 0.2,
    fHoleX: 0.1,
    pegR: 0.02,
    endpin: 0.22,
  );
  static const bass = _Build(
    neck: 0.44,
    head: 0.3,
    ribs: 0.19,
    arch: 0.025,
    neckW: 0.03,
    neckDepth: 0.05,
    boardEnd: 0.42,
    bridgeY: 0.58,
    bridgeH: 0.14,
    fHole: 0.19,
    fHoleX: 0.098,
    pegR: 0.018,
    endpin: 0.14,
    sloped: true,
  );

  static _Build of(InstrumentType type) => switch (type) {
        InstrumentType.violin => violin,
        InstrumentType.viola => viola,
        InstrumentType.cello => cello,
        InstrumentType.doubleBass => bass,
      };

  /// Neck end of the body to the nut.
  final double neck;

  /// Nut to the top of the scroll.
  final double head;
  final double ribs;
  final double arch;

  /// Half the fingerboard's width at the nut.
  final double neckW;

  /// Neck plus fingerboard, front to back.
  final double neckDepth;
  final double boardEnd;
  final double bridgeY;
  final double bridgeH;
  final double fHole;
  final double fHoleX;
  final double pegR;
  final double endpin;
  int get pegs => 4;
  final bool sloped;
  final bool chinrest;

  /// Right half of the outline, from the neck to the end button, as cubic
  /// segments (control 1, control 2, end).
  List<(Offset, Offset, Offset)> get rightHalf => [
        if (sloped) ...[
          (const Offset(0.07, 0), const Offset(0.12, 0.05), const Offset(0.172, 0.118)),
          (const Offset(0.205, 0.16), const Offset(0.228, 0.19), const Offset(0.228, 0.24)),
          (const Offset(0.228, 0.28), const Offset(0.205, 0.292), const Offset(0.201, 0.315)),
        ] else ...[
          (const Offset(0.13, 0), const Offset(0.237, 0.055), const Offset(0.237, 0.18)),
          (const Offset(0.237, 0.25), const Offset(0.205, 0.288), const Offset(0.201, 0.315)),
        ],
        (const Offset(0.199, 0.33), const Offset(0.21, 0.346), const Offset(0.228, 0.356)),
        (const Offset(0.19, 0.352), const Offset(0.156, 0.39), const Offset(0.156, 0.46)),
        (const Offset(0.156, 0.53), const Offset(0.19, 0.6), const Offset(0.232, 0.594)),
        (const Offset(0.216, 0.606), const Offset(0.21, 0.618), const Offset(0.21, 0.636)),
        (const Offset(0.21, 0.66), const Offset(0.293, 0.68), const Offset(0.293, 0.78)),
        (const Offset(0.293, 0.915), const Offset(0.15, 1), Offset.zero.translate(0, 1)),
      ];

  double get _top => -(neck + head) - 0.015;

  Rect get frontBounds => Rect.fromLTRB(-0.33, _top, 0.33, 1 + math.max(endpin, 0.02) + 0.02);

  Rect get sideBounds {
    final r = ribs / 2;
    final w = math.max(r + arch + bridgeH + 0.02, 0.1);
    return Rect.fromLTRB(-w, _top, w, 1 + math.max(endpin, 0.02) + 0.02);
  }

  Rect get headBounds {
    final g = _SideGeometry(this);
    final c = Offset(g.scroll.dx + 0.02, -neck - head * 0.45);
    final h = head * 1.3;
    return Rect.fromCenter(center: c, width: h * 0.75, height: h);
  }
}

/// Side-view anchor points shared by the neck, head and strings.
final class _SideGeometry {
  _SideGeometry(this.b)
      : nut = Offset(b.ribs / 2 * 0.5 + 0.004, -b.neck),
        bridgeTop = Offset(b.ribs / 2 + b.arch * 0.98 + b.bridgeH, b.bridgeY);

  final _Build b;
  final Offset nut;
  final Offset bridgeTop;

  double get boardDepth => b.neckDepth * 0.32;
  double get neckDepth => b.neckDepth;

  /// The fingerboard's top surface runs just under the strings.
  Offset get boardEndTop {
    final t = (b.boardEnd + b.neck) / (b.bridgeY + b.neck);
    final onString = Offset.lerp(nut, bridgeTop, t)!;
    return onString - Offset(b.bridgeH * 0.16, 0);
  }

  Offset get heelTop => Offset(b.ribs / 2 + 0.002, 0);

  double get scrollR => b.head * 0.2;

  Offset get scroll => Offset(nut.dx - neckDepth * 0.55, -b.neck - b.head + scrollR);
}
