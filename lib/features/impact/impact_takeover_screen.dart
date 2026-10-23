import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/reading_value.dart';
import '../../core/widgets/rise_in.dart';
import '../../core/widgets/status_badge.dart';
import '../../domain/thresholds/alert.dart';
import '../../domain/thresholds/threshold_config.dart';

/// Hero moment: a knock or a fall, full screen, the moment it happens.
class ImpactTakeoverScreen extends StatefulWidget {
  const ImpactTakeoverScreen({
    super.key,
    required this.alert,
    required this.instrumentName,
    required this.displayTime,
    required this.onViewInstrument,
    required this.onDismiss,
  });

  final Alert alert;
  final String instrumentName;

  /// When it happened, already shifted to display time.
  final DateTime displayTime;
  final VoidCallback onViewInstrument;
  final VoidCallback onDismiss;

  /// Fades in over the current screen, settling from a slight zoom.
  static Route<void> route(ImpactTakeoverScreen screen) => PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Motion.medium,
        reverseTransitionDuration: Motion.medium,
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Motion.enter);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 1.04, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );

  @override
  State<ImpactTakeoverScreen> createState() => _ImpactTakeoverScreenState();
}

class _ImpactTakeoverScreenState extends State<ImpactTakeoverScreen>
    with SingleTickerProviderStateMixin {
  late final _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final alert = widget.alert;
    final mark = colors.status(alert.severity);
    final isFall = alert.rule == ThresholdRule.freeFall;
    final time = TimeOfDay.fromDateTime(widget.displayTime).format(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _ripple,
            builder: (_, _) => CustomPaint(
              painter: _ShockwavePainter(progress: _ripple.value, color: mark),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  Eyebrow(isFall ? 'Drop recorded' : 'Impact recorded', color: colors.statusInk(alert.severity)),
                  const SizedBox(height: Space.l),
                  ReadingValue(
                    value: isFall ? alert.measured.toDouble() : alert.measured / 10,
                    unit: isFall ? 'ms' : 'g',
                    decimals: isFall ? 0 : 1,
                    size: ReadingSize.hero,
                    countFrom: 0,
                  ),
                  const SizedBox(height: Space.l),
                  StatusBadge(alert.severity, large: true).riseIn(2),
                  const SizedBox(height: Space.xl),
                  Text(alert.title, style: text.headlineLarge, textAlign: TextAlign.center).riseIn(3),
                  const SizedBox(height: Space.s),
                  Text(
                    '${widget.instrumentName} · $time',
                    style: text.bodyMedium!.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ).riseIn(4),
                  const SizedBox(height: Space.xl),
                  const Hairline(ornament: true, indent: Space.xxl).riseIn(5),
                  const SizedBox(height: Space.xl),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      alert.whatToDo,
                      style: AelosText.of(context).note.copyWith(color: colors.text),
                      textAlign: TextAlign.center,
                    ),
                  ).riseIn(6),
                  const Spacer(flex: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.onViewInstrument,
                      child: const Text('View instrument'),
                    ),
                  ).riseIn(7),
                  const SizedBox(height: Space.s),
                  TextButton(onPressed: widget.onDismiss, child: const Text('Dismiss')),
                  const SizedBox(height: Space.s),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three rings leave the centre in quick succession, like the knock itself
/// travelling through the case, then fade. A faint tint lingers behind.
class _ShockwavePainter extends CustomPainter {
  const _ShockwavePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.34);
    final reach = size.longestSide * 0.75;

    canvas.drawCircle(
      centre,
      reach,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.14 * Curves.easeOut.transform(progress.clamp(0, 0.3) / 0.3)),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: reach * 0.7)),
    );

    for (var i = 0; i < 3; i++) {
      final start = i * 0.12;
      final t = ((progress - start) / 0.62).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOutCubic.transform(t);
      canvas.drawCircle(
        centre,
        48 + (reach - 48) * eased,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 - i * 0.4
          ..color = color.withValues(alpha: (1 - t) * (0.8 - i * 0.2)),
      );
    }
  }

  @override
  bool shouldRepaint(_ShockwavePainter old) => old.progress != progress || old.color != color;
}
