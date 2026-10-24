import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/f_hole.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/reading_value.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/instrument_data.dart';
import '../../domain/models/condition_status.dart';
import '../../domain/models/event_report.dart';
import 'luthier_fleet.dart';
import 'luthier_format.dart';

/// Content width on tablets and the web; phones use the full width.
const luthierMaxWidth = 720.0;

/// Centres [children] in a scrolling column at [luthierMaxWidth].
class LuthierPage extends StatelessWidget {
  const LuthierPage({super.key, required this.children, this.bottom = Space.xxxl});

  final List<Widget> children;
  final double bottom;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - Space.page * 2).clamp(0.0, luthierMaxWidth);
          final side = (constraints.maxWidth - width) / 2;
          return ListView(
            padding: EdgeInsets.fromLTRB(side, Space.l, side, bottom),
            children: children,
          );
        },
      );
}

/// Eyebrow, serif title and a muted line, with the f-hole as a watermark.
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.watermark = true,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool watermark;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (watermark)
          Positioned(
            right: Space.s,
            top: -Space.s,
            child: FHole(height: 104, color: colors.accent.withValues(alpha: 0.10)),
          ),
        Padding(
          padding: const EdgeInsets.only(right: Space.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(eyebrow, color: colors.accentInk),
              const SizedBox(height: Space.s),
              Text(title, style: text.displaySmall),
              if (subtitle != null) ...[
                const SizedBox(height: Space.s),
                Text(subtitle!, style: text.bodyMedium!.copyWith(color: colors.textMuted)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "EYEBROW ———————— 3", the programme-style section rule.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.count, this.ornament = false});

  final String title;
  final int? count;
  final bool ornament;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Row(
        children: [
          Eyebrow(title),
          const SizedBox(width: Space.m),
          Expanded(child: Hairline(ornament: ornament)),
          if (count != null) ...[
            const SizedBox(width: Space.m),
            Text('$count', style: text.labelMedium),
          ],
        ],
      ),
    );
  }
}

/// The instrument's photo, cropped and rounded, or the f-hole if none.
class InstrumentThumb extends StatelessWidget {
  const InstrumentThumb({super.key, required this.data, required this.width, required this.height});

  final InstrumentData data;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final empty = ColoredBox(
      color: colors.surfaceRaised,
      child: Center(child: FHole(height: height * 0.6, color: colors.accent.withValues(alpha: 0.5))),
    );
    final photo = data.instrument.photo;
    final Widget image = data.photoBytes != null
        ? Image.memory(data.photoBytes!, fit: BoxFit.cover, errorBuilder: (_, _, _) => empty)
        : photo == null
            ? empty
            : Image.asset(photo, fit: BoxFit.cover, errorBuilder: (_, _, _) => empty);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radii.s),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radii.s),
                border: Border.all(color: colors.hairline, width: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A breathing sage dot with "LIVE": this sensor is streaming now.
class LiveMark extends StatelessWidget {
  const LiveMark({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: Space.s - 1,
          height: Space.s - 1,
          decoration: BoxDecoration(color: colors.calm, shape: BoxShape.circle),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 1, end: 0.3, duration: Motion.chartDraw, curve: Curves.easeInOut),
        const SizedBox(width: Space.xs + 2),
        Eyebrow('Live', color: colors.calmInk),
      ],
    );
  }
}

/// Initials in a hairline circle, for people.
class Monogram extends StatelessWidget {
  const Monogram(this.name, {super.key, this.size = 40, this.filled = false});

  final String name;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? colors.accent.withValues(alpha: 0.12) : colors.surface,
        border: Border.all(color: filled ? colors.accent : colors.hairline, width: 0.9),
      ),
      child: Text(
        initials(name),
        style: text.titleLarge!.copyWith(
          fontSize: size * 0.42,
          height: 1,
          color: colors.accentInk,
        ),
      ),
    );
  }
}

/// Pill-shaped segmented control: the selected segment is inked.
class LuthierSegmented<T> extends StatelessWidget {
  const LuthierSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.all(Radii.pill),
        border: Border.all(color: colors.hairline, width: 0.8),
      ),
      child: Row(
        children: [
          for (final (value, label) in segments)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: Motion.medium,
                  curve: Motion.emphasis,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected ? colors.text : colors.surface.withValues(alpha: 0),
                    borderRadius: const BorderRadius.all(Radii.pill),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: Motion.medium,
                    style: text.labelLarge!.copyWith(
                      color: value == selected ? colors.background : colors.textMuted,
                    ),
                    child: Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One instrument of the fleet: photo, name, renter, status, humidity and
/// last sync. [detailed] adds the rental plan.
class FleetCard extends StatelessWidget {
  const FleetCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.live = false,
    this.liveHumidity,
    this.detailed = false,
  });

  final FleetEntry entry;
  final VoidCallback onTap;
  final bool live;
  final double? liveHumidity;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final data = entry.data;
    final instrument = data.instrument;
    final latest = data.latestReading;
    final humidity = liveHumidity ?? latest?.humidity;
    final rental = entry.rental;
    final synced = live
        ? 'Streaming now'
        : latest == null
            ? 'No records yet'
            : 'Synced ${LuthierFormat.ago(data.displayTime(latest.time))}';

    return AelosCard(
      padding: const EdgeInsets.all(Space.m),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'fleet-photo-${entry.id}',
                child: InstrumentThumb(data: data, width: 76, height: 104),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: SizedBox(
                  height: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${instrument.type.label} · ${instrument.dateLabel}'.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AelosText.of(context).eyebrow,
                            ),
                          ),
                          if (live) const LiveMark(),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        instrument.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            rental.inWorkshop ? Icons.handyman_outlined : Icons.person_outline_rounded,
                            size: 15,
                            color: colors.textFaint,
                          ),
                          const SizedBox(width: Space.xs + 2),
                          Expanded(
                            child: Text(
                              rental.inWorkshop ? 'In the workshop' : rental.renterName ?? 'Rented out',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(entry.status),
                          const Spacer(),
                          if (humidity != null)
                            ReadingValue(value: humidity, unit: '%', size: ReadingSize.small),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          const Hairline(),
          const SizedBox(height: Space.s + 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  detailed && !rental.inWorkshop && rental.since != null
                      ? 'Since ${LuthierFormat.date(rental.since!.toLocal())} · ${LuthierFormat.span(rental.since!.toLocal())}'
                      : detailed && rental.inWorkshop
                          ? 'Available · ${rental.plan ?? 'ready to rent'}'
                          : instrument.origin ?? instrument.maker ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium!.copyWith(color: colors.textFaint),
                ),
              ),
              const SizedBox(width: Space.s),
              Icon(
                live ? Icons.sensors_rounded : Icons.history_rounded,
                size: 14,
                color: live ? colors.calm : colors.textFaint,
              ),
              const SizedBox(width: Space.xs),
              Text(
                synced,
                style: text.labelMedium!.copyWith(color: live ? colors.calmInk : colors.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How a report's status reads to the luthier.
extension ReportStatusLook on ReportStatus {
  String get luthierLabel => switch (this) {
        ReportStatus.submitted => 'New',
        ReportStatus.reviewed => 'Reviewed',
        ReportStatus.inspectionScheduled => 'Inspection booked',
        ReportStatus.resolved => 'Resolved',
      };

  IconData get icon => switch (this) {
        ReportStatus.submitted => Icons.mark_email_unread_outlined,
        ReportStatus.reviewed => Icons.visibility_outlined,
        ReportStatus.inspectionScheduled => Icons.event_available_outlined,
        ReportStatus.resolved => Icons.task_alt_rounded,
      };
}

/// Pill with icon and word for a report's progress.
class ReportStatusPill extends StatelessWidget {
  const ReportStatusPill(this.status, {super.key});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final (fill, mark, ink) = switch (status) {
      ReportStatus.submitted => (colors.accent.withValues(alpha: 0.16), colors.accent, colors.accentInk),
      ReportStatus.reviewed => (colors.hairline, colors.textMuted, colors.textMuted),
      ReportStatus.inspectionScheduled => (
          colors.statusTint(ConditionStatus.calm),
          colors.calm,
          colors.calmInk,
        ),
      ReportStatus.resolved => (colors.surface.withValues(alpha: 0), colors.textFaint, colors.textMuted),
    };
    return AnimatedSwitcher(
      duration: Motion.medium,
      child: Container(
        key: ValueKey(status),
        padding: const EdgeInsets.symmetric(horizontal: Space.m - 2, vertical: Space.xs + 1),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.all(Radii.pill),
          border: status == ReportStatus.resolved ? Border.all(color: colors.hairline) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 15, color: mark),
            const SizedBox(width: Space.xs + 2),
            Text(status.luthierLabel, style: text.labelMedium!.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}

/// A quiet empty state: a faint f-hole and an italic line.
class LuthierEmpty extends StatelessWidget {
  const LuthierEmpty(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xl),
      child: Row(
        children: [
          FHole(height: 56, color: colors.accent.withValues(alpha: 0.35)),
          const SizedBox(width: Space.l),
          Expanded(child: Text(message, style: AelosText.of(context).note)),
        ],
      ),
    );
  }
}
