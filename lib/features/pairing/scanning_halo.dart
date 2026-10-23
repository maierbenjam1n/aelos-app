import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/widgets/f_hole.dart';

/// The f-hole draws itself in while hairline rings drift outward from it,
/// slowly, like sound leaving the instrument. [active] stops the rings once a
/// sensor is linked.
class ScanningHalo extends StatefulWidget {
  const ScanningHalo({super.key, this.size = 260, this.active = true});

  final double size;
  final bool active;

  @override
  State<ScanningHalo> createState() => _ScanningHaloState();
}

class _ScanningHaloState extends State<ScanningHalo> with TickerProviderStateMixin {
  late final _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();
  late final _rings = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRings();
  }

  @override
  void didUpdateWidget(ScanningHalo old) {
    super.didUpdateWidget(old);
    _syncRings();
  }

  void _syncRings() {
    final animate = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_rings.isAnimating) {
      _rings.repeat();
    } else if (!animate && _rings.isAnimating) {
      _rings.stop();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _rings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final fHoleHeight = widget.size * 0.46;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_draw, _rings]),
        builder: (context, _) => CustomPaint(
          painter: _RingsPainter(
            phase: _rings.value,
            color: colors.accent,
            visible: widget.active ? 1 : 0,
          ),
          child: Center(
            child: CustomPaint(
              size: Size(fHoleHeight / 4, fHoleHeight),
              painter: FHolePainter(
                colors.accent,
                progress: Curves.easeInOutCubic.transform(_draw.value),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.phase, required this.color, required this.visible});

  final double phase;
  final Color color;
  final double visible;

  static const _count = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (visible == 0) return;
    final centre = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    for (var i = 0; i < _count; i++) {
      final t = (phase + i / _count) % 1;
      // Rings start just outside the f-hole and fade as they reach the edge.
      final radius = maxRadius * (0.3 + 0.7 * Curves.easeOut.transform(t));
      final alpha = (1 - t) * 0.7 * visible;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = color.withValues(alpha: alpha),
      );
    }
    // A fixed faint ring gives the composition an edge when the rings are thin.
    canvas.drawCircle(
      centre,
      maxRadius * 0.3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = color.withValues(alpha: 0.25 * visible),
    );
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.phase != phase || old.color != color || old.visible != visible;
}
