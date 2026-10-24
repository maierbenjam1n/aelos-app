import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../domain/models/event_report.dart';
import '../../domain/models/instrument.dart';
import 'instrument_drawing.dart';
import 'report_copy.dart';
import 'report_photo_image.dart';

/// A camera-guide frame for one angle: the instrument drawn in hairline
/// inside viewfinder brackets, or the captured photo once there is one.
class AngleGuide extends StatefulWidget {
  const AngleGuide({
    super.key,
    required this.type,
    required this.angle,
    this.photo,
  });

  final InstrumentType type;
  final PhotoAngle angle;
  final ReportPhoto? photo;

  @override
  State<AngleGuide> createState() => _AngleGuideState();
}

class _AngleGuideState extends State<AngleGuide> with SingleTickerProviderStateMixin {
  late final _draw = AnimationController(vsync: this, duration: Motion.chartDraw * 1.4);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _draw.value = 1;
    } else if (!_draw.isAnimating && _draw.value == 0) {
      _draw.forward();
    }
  }

  @override
  void didUpdateWidget(AngleGuide old) {
    super.didUpdateWidget(old);
    if (old.angle != widget.angle || old.type != widget.type) _draw.forward(from: 0);
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final photo = widget.photo;
    final onPhoto = photo != null;
    final label = AelosText.of(context).eyebrow;
    final labelColor = onPhoto ? AelosPalette.ivory : colors.accentInk;
    const radius = BorderRadius.all(Radii.l);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(color: colors.hairline, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _DotGridPainter(colors.hairline)),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.xxxl, Space.xl, Space.xxl),
              child: CustomPaint(
                painter: InstrumentDrawingPainter(
                  type: widget.type,
                  angle: widget.angle,
                  ink: colors.accent,
                  detail: colors.textFaint,
                  progress: _draw,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: Motion.slow,
              switchInCurve: Motion.enter,
              switchOutCurve: Motion.exit,
              child: photo == null
                  ? const SizedBox.expand()
                  : Stack(
                      key: ValueKey(photo),
                      fit: StackFit.expand,
                      children: [
                        ReportPhotoImage(photo),
                        // Keeps the labels legible on any photo.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, 0.22, 0.7, 1],
                              colors: [
                                AelosPalette.walnutDeep.withValues(alpha: 0.55),
                                AelosPalette.walnutDeep.withValues(alpha: 0),
                                AelosPalette.walnutDeep.withValues(alpha: 0),
                                AelosPalette.walnutDeep.withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _ViewfinderPainter(
                  color: onPhoto ? AelosPalette.ivory : colors.accent,
                  ruler: !onPhoto,
                  faint: colors.textFaint,
                ),
              ),
            ),
            Positioned(
              left: Space.xl + Space.xs,
              top: Space.l + Space.xs,
              child: Text(
                '${widget.angle.short} view'.toUpperCase(),
                style: label.copyWith(color: labelColor),
              ),
            ),
            Positioned(
              right: Space.xl + Space.xs,
              top: Space.l + Space.xs,
              child: Text(
                widget.type.label.toUpperCase(),
                style: label.copyWith(color: onPhoto ? labelColor : colors.textFaint),
              ),
            ),
            if (onPhoto)
              Positioned(
                left: 0,
                right: 0,
                bottom: Space.l + Space.xs,
                child: Center(child: _CapturedPill(color: labelColor)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CapturedPill extends StatelessWidget {
  const _CapturedPill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AelosPalette.walnutDeep.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.all(Radii.pill),
        border: Border.all(color: AelosPalette.ivory.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs + 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 16, color: color),
            const SizedBox(width: Space.xs + 2),
            Text('In the frame', style: text.labelMedium!.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Corner brackets and ruler ticks, like a camera's guide.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.color, required this.faint, required this.ruler});

  final Color color;
  final Color faint;

  /// Ticks on the empty guide only; a photo needs no ruler.
  final bool ruler;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 14.0;
    const arm = 22.0;
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    final r = Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset);
    for (final (corner, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx * arm, corner.dy)
          ..lineTo(corner.dx + dx * 4, corner.dy)
          ..quadraticBezierTo(corner.dx, corner.dy, corner.dx, corner.dy + dy * 4)
          ..lineTo(corner.dx, corner.dy + dy * arm),
        bracket,
      );
    }

    if (!ruler) return;
    // Ruler ticks down both long edges, a major one every fifth.
    final tick = Paint()
      ..strokeWidth = 0.7
      ..color = faint.withValues(alpha: faint.a * 0.7);
    final top = r.top + arm + 14;
    final bottom = r.bottom - arm - 14;
    const step = 9.0;
    final count = ((bottom - top) / step).floor();
    final offset = (bottom - top - count * step) / 2;
    for (var i = 0; i <= count; i++) {
      final y = top + offset + i * step;
      final len = i % 5 == 0 ? 7.0 : 3.5;
      canvas
        ..drawLine(Offset(r.left, y), Offset(r.left + len, y), tick)
        ..drawLine(Offset(r.right, y), Offset(r.right - len, y), tick);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      old.color != color || old.faint != faint || old.ruler != ruler;
}

/// A faint dot grid, like a cutting mat, behind the drawing.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 18.0;
    final dot = Paint()..color = color.withValues(alpha: math.min(1, color.a * 1.4));
    final cols = (size.width / step).floor();
    final rows = (size.height / step).floor();
    final ox = (size.width - cols * step) / 2;
    final oy = (size.height - rows * step) / 2;
    for (var i = 0; i <= cols; i++) {
      for (var j = 0; j <= rows; j++) {
        canvas.drawCircle(Offset(ox + i * step, oy + j * step), 0.7, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
