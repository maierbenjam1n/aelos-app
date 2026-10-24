import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/rise_in.dart';
import '../../domain/models/account.dart';
import '../../domain/models/event_report.dart';
import '../../domain/models/instrument.dart';
import 'explanation_step.dart';
import 'instrument_drawing.dart';
import 'report_copy.dart';
import 'report_photo_image.dart';

/// Last step: the photos, the account and where it goes.
class ReviewStep extends StatelessWidget {
  const ReviewStep({
    super.key,
    required this.event,
    required this.type,
    required this.photos,
    required this.causes,
    required this.explanation,
    required this.luthier,
    required this.busy,
    required this.onEditExplanation,
    required this.onOpenAngle,
    required this.onSubmit,
  });

  final EventSummary event;
  final InstrumentType type;
  final Map<PhotoAngle, ReportPhoto> photos;
  final List<String> causes;
  final String explanation;

  /// The renter's luthier; null for an owner's own record.
  final Luthier? luthier;
  final bool busy;
  final VoidCallback onEditExplanation;
  final ValueChanged<PhotoAngle> onOpenAngle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AelosColors.of(context);
    final count = photos.length;
    final luthier = this.luthier;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(luthier == null ? 'Ready to add' : 'Ready to send', style: text.displaySmall).riseIn(0),
                const SizedBox(height: Space.s),
                Text(
                  '${count == 0 ? 'No photos' : count == 1 ? 'One photo' : '$count photos'} '
                  '${causes.isEmpty && explanation.isEmpty ? 'and no notes' : 'and your notes'}, '
                  'beside the signed record.',
                  style: text.bodyMedium!.copyWith(color: colors.textMuted),
                ).riseIn(1),
                const SizedBox(height: Space.xl),
                EventSummaryCard(event: event, compact: true).riseIn(2),
                const SizedBox(height: Space.xxl),
                _SectionHeader(
                  title: 'Photos',
                  trailing: '$count of ${PhotoAngle.values.length}',
                ).riseIn(3),
                const SizedBox(height: Space.m),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Space.m,
                  crossAxisSpacing: Space.s,
                  childAspectRatio: 0.62,
                  children: [
                    for (final angle in PhotoAngle.values)
                      _PhotoTile(
                        angle: angle,
                        type: type,
                        photo: photos[angle],
                        onTap: () => onOpenAngle(angle),
                      ),
                  ],
                ).riseIn(4),
                const SizedBox(height: Space.xxl),
                _SectionHeader(title: 'Your account', action: 'Edit', onAction: onEditExplanation).riseIn(5),
                const SizedBox(height: Space.m),
                AelosCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (causes.isNotEmpty) ...[
                        Wrap(
                          spacing: Space.s,
                          runSpacing: Space.s,
                          children: [for (final c in causes) CauseChip(label: c, selected: true)],
                        ),
                        if (explanation.isNotEmpty) const SizedBox(height: Space.m),
                      ],
                      if (explanation.isNotEmpty)
                        Text(
                          explanation,
                          style: text.titleLarge!.copyWith(fontWeight: FontWeight.w400, height: 1.4),
                        )
                      else if (causes.isEmpty)
                        Text('No notes added.', style: AelosText.of(context).note),
                    ],
                  ),
                ).riseIn(6),
                const SizedBox(height: Space.xxl),
                const _SectionHeader(title: 'Goes to').riseIn(7),
                const SizedBox(height: Space.m),
                _Destination(luthier: luthier).riseIn(8),
              ],
            ),
          ),
        ),
        StepActions(
          children: [
            FilledButton.icon(
              onPressed: busy ? null : onSubmit,
              icon: Icon(
                luthier == null ? Icons.library_add_check_outlined : Icons.send_rounded,
                size: 18,
              ),
              label: Text(luthier == null ? 'Add to condition history' : 'Send to ${luthier.workshop}'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing, this.action, this.onAction});

  final String title;
  final String? trailing;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: Space.xxl,
      child: Row(
        children: [
          Eyebrow(title),
          const Spacer(),
          if (trailing != null) Text(trailing!, style: text.labelMedium),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: Space.s),
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.angle, required this.type, required this.photo, required this.onTap});

  final PhotoAngle angle;
  final InstrumentType type;
  final ReportPhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final photo = this.photo;
    const radius = BorderRadius.all(Radii.m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: colors.hairline, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: photo != null
                  ? ReportPhotoImage(photo, cacheWidth: 360)
                  : Padding(
                      padding: const EdgeInsets.all(Space.m),
                      child: CustomPaint(
                        painter: InstrumentDrawingPainter(
                          type: type,
                          angle: angle,
                          ink: colors.textFaint.withValues(alpha: 0.6),
                          detail: colors.hairline,
                        ),
                        size: Size.infinite,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: Space.xs + 2),
        Text(angle.short, style: text.labelMedium!.copyWith(color: colors.text)),
        Text(
          photo != null ? 'Taken' : angle.optional ? 'Not needed' : 'Skipped · add',
          style: text.bodySmall!.copyWith(color: photo != null ? colors.textMuted : colors.textFaint),
        ),
      ],
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({required this.luthier});

  final Luthier? luthier;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final luthier = this.luthier;
    return AelosCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.accent, width: 1),
            ),
            child: luthier == null
                ? Icon(Icons.history_edu_outlined, size: 20, color: colors.accent)
                : Text(
                    initialsOf(luthier.workshop),
                    style: text.titleLarge!.copyWith(color: colors.accentInk, height: 1),
                  ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(luthier?.workshop ?? 'Your condition history', style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  luthier == null
                      ? 'Kept beside the signed record of this event.'
                      : '${luthier.master} · ${luthier.city}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: Space.s),
                Text(
                  luthier == null
                      ? 'Your notes and photos are yours: the sensor signs the measurements, not the account.'
                      : 'Your luthier sees the photos with the signed record and gets back to you.',
                  style: AelosText.of(context).note.copyWith(fontSize: text.bodyLarge!.fontSize),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
