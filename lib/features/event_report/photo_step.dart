import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/rise_in.dart';
import '../../domain/models/event_report.dart';
import '../../domain/models/instrument.dart';
import 'angle_guide.dart';
import 'explanation_step.dart';
import 'photo_source.dart';
import 'report_copy.dart';

/// One guided photo: the drawing shows how to frame it, then the photo
/// takes its place with Retake and Continue.
class PhotoStep extends StatelessWidget {
  const PhotoStep({
    super.key,
    required this.type,
    required this.angle,
    required this.photo,
    required this.busy,
    required this.message,
    required this.onPick,
    required this.onRetake,
    required this.onContinue,
    required this.onSkip,
  });

  final InstrumentType type;
  final PhotoAngle angle;
  final ReportPhoto? photo;

  /// The camera or library is open.
  final bool busy;

  /// A calm note after a refused permission or a failed pick.
  final String? message;
  final ValueChanged<PhotoOrigin> onPick;
  final VoidCallback onRetake;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AelosColors.of(context);
    final index = PhotoAngle.values.indexOf(angle) + 1;
    final captured = photo != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: Space.xxl,
                child: Row(
                  children: [
                    Eyebrow('Photo $index of ${PhotoAngle.values.length}'),
                    if (angle.optional) ...[
                      const SizedBox(width: Space.s),
                      Eyebrow('· Optional', color: colors.accentInk),
                    ],
                    const Spacer(),
                    if (!captured)
                      TextButton(
                        onPressed: busy ? null : onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.textMuted,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: Space.s),
                        ),
                        child: const Text('Skip'),
                      ),
                  ],
                ),
              ).riseIn(0),
              Text(angle.title, style: text.headlineLarge).riseIn(1),
              const SizedBox(height: Space.xs),
              Text(
                angle.guidance,
                style: text.bodyMedium!.copyWith(color: colors.textMuted),
              ).riseIn(2),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            child: AngleGuide(type: type, angle: angle, photo: photo),
          ).riseIn(3),
        ),
        // The tip gives way to the frame on short screens.
        if (MediaQuery.sizeOf(context).height > 700) ...[
          const SizedBox(height: Space.m),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.page + Space.xs),
            child: Text(
              angle.tip,
              style: AelosText.of(context).note.copyWith(fontSize: text.bodyLarge!.fontSize),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ).riseIn(4),
        ],
        const SizedBox(height: Space.m),
        StepActions(
          above: message == null ? null : _CalmMessage(message!),
          children: captured
              ? [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : onRetake,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      Expanded(
                        child: FilledButton(onPressed: onContinue, child: const Text('Continue')),
                      ),
                    ],
                  ),
                ]
              : [
                  FilledButton.icon(
                    onPressed: busy ? null : () => onPick(PhotoOrigin.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: const Text('Take photo'),
                  ),
                  const SizedBox(height: Space.s),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => onPick(PhotoOrigin.library),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Choose from library'),
                  ),
                ],
        ),
      ],
    );
  }
}

class _CalmMessage extends StatelessWidget {
  const _CalmMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline_rounded, size: 18, color: colors.accent),
        ),
        const SizedBox(width: Space.s),
        Expanded(child: Text(message, style: text.bodySmall!.copyWith(color: colors.text))),
      ],
    );
  }
}
