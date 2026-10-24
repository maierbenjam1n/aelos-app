import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/f_hole.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/rise_in.dart';

/// The calm close of the flow: a seal draws itself, the f-hole is cut into
/// it, and a line says where the report went.
class ReportSent extends StatefulWidget {
  const ReportSent({
    super.key,
    required this.title,
    required this.detail,
    required this.onDone,
  });

  final String title;
  final String detail;
  final VoidCallback onDone;

  @override
  State<ReportSent> createState() => _ReportSentState();
}

class _ReportSentState extends State<ReportSent> with SingleTickerProviderStateMixin {
  late final _seal = AnimationController(vsync: this, duration: Motion.chartDraw * 1.5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _seal.value = 1;
    } else if (_seal.value == 0) {
      _seal.forward();
    }
  }

  @override
  void dispose() {
    _seal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.page),
        child: Column(
          children: [
            const Spacer(flex: 3),
            SizedBox.square(
              dimension: 168,
              child: CustomPaint(
                painter: _SealPainter(progress: _seal, ink: colors.accent, ground: colors.background),
              ),
            ),
            const SizedBox(height: Space.xxl),
            Text(widget.title, style: text.headlineLarge, textAlign: TextAlign.center).riseIn(8),
            const SizedBox(height: Space.m),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                widget.detail,
                style: AelosText.of(context).note.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ).riseIn(10),
            const SizedBox(height: Space.xl),
            const Hairline(ornament: true, indent: Space.xxxl * 1.5).riseIn(12),
            const Spacer(flex: 4),
            TextButton(onPressed: widget.onDone, child: const Text('Done')).riseIn(14),
            const SizedBox(height: Space.l),
          ],
        ),
      ),
    );
  }
}

/// Rings and beads stamp in, then the f-hole is drawn into a varnish boss.
class _SealPainter extends CustomPainter {
  _SealPainter({required this.progress, required this.ink, required this.ground})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color ink;
  final Color ground;

  static double _phase(double p, double a, double b) =>
      Curves.easeInOutCubic.transform(((p - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    Paint ring(double width, double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: alpha);

    final outer = _phase(p, 0, 0.45);
    final inner = _phase(p, 0.1, 0.55);
    canvas
      ..drawArc(Rect.fromCircle(center: c, radius: r * 0.96), -math.pi / 2, 2 * math.pi * outer, false, ring(1.2, 1))
      ..drawArc(Rect.fromCircle(center: c, radius: r * 0.8), math.pi / 2, 2 * math.pi * inner, false, ring(0.8, 0.8));

    final beads = _phase(p, 0.3, 0.7);
    final bead = Paint()..color = ink.withValues(alpha: 0.7);
    const count = 60;
    for (var i = 0; i < (count * beads).round(); i++) {
      final th = -math.pi / 2 + 2 * math.pi * i / count;
      canvas.drawCircle(c + Offset(math.cos(th), math.sin(th)) * r * 0.88, 1, bead);
    }

    final boss = Curves.easeOutCubic.transform(((p - 0.4) / 0.3).clamp(0.0, 1.0));
    if (boss > 0) {
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..scale(0.92 + 0.08 * boss)
        ..translate(-c.dx, -c.dy)
        ..drawCircle(c, r * 0.62, Paint()..color = ink.withValues(alpha: 0.12 * boss))
        ..drawCircle(c, r * 0.62, ring(0.8, 0.5 * boss))
        ..restore();
    }

    final hole = _phase(p, 0.5, 1);
    if (hole > 0) {
      final h = r * 0.92;
      canvas
        ..save()
        ..translate(c.dx - h / 8, c.dy - h / 2);
      FHolePainter(ink, progress: hole).paint(canvas, Size(h / 4, h));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.ink != ink || old.ground != ground;
}
