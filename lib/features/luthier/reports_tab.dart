import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/f_hole.dart';
import '../../core/widgets/rise_in.dart';
import '../../domain/models/event_report.dart';
import 'luthier_fleet.dart';
import 'luthier_format.dart';
import 'luthier_widgets.dart';
import 'report_review_screen.dart';

/// Event reports renters have sent to this workshop, unreviewed first.
class ReportsTab extends ConsumerWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(fleetReportsProvider);
    final open = [for (final r in reports) if (r.needsReview) r];
    final progress = [
      for (final r in reports)
        if (r.report.status == ReportStatus.reviewed ||
            r.report.status == ReportStatus.inspectionScheduled)
          r,
    ];
    final closed = [for (final r in reports) if (r.report.status == ReportStatus.resolved) r];

    var i = 0;
    List<Widget> section(String title, List<FleetReport> items) => [
          SectionHeader(title, count: items.length).riseIn(i++),
          for (final r in items)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: ReportCard(
                report: r,
                onTap: () => ReportReviewScreen.open(context, r.report.id),
              ),
            ).riseIn(i++),
          const SizedBox(height: Space.l),
        ];

    return LuthierPage(
      children: [
        PageHeading(
          eyebrow: 'From your renters',
          title: 'Reports',
          subtitle: open.isEmpty
              ? 'Nothing waiting for review.'
              : '${open.length} waiting for your review',
        ).riseIn(i++),
        const SizedBox(height: Space.xl),
        if (reports.isEmpty)
          const LuthierEmpty(
            'When a renter documents an event, their account and photos arrive here.',
          ),
        if (open.isNotEmpty) ...section('To review', open),
        if (progress.isNotEmpty) ...section('In hand', progress),
        if (closed.isNotEmpty) ...section('Resolved', closed),
      ],
    );
  }
}

/// A report in the inbox: first photo, event, instrument, author, status.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, required this.onTap});

  final FleetReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final r = report.report;
    final photo = r.photos.firstOrNull;
    final faded = r.status == ReportStatus.resolved;
    return AelosCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.m),
      child: Opacity(
        opacity: faded ? 0.72 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportPhotoThumb(photo: photo, width: 76, height: 96),
            const SizedBox(width: Space.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(r.authorName, color: r.status == ReportStatus.submitted ? colors.accentInk : null),
                  const SizedBox(height: Space.xs),
                  Text(r.eventTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    report.entry?.data.instrument.name ?? r.instrumentId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: Space.m),
                  Row(
                    children: [
                      ReportStatusPill(r.status),
                      const Spacer(),
                      Text(
                        LuthierFormat.when(report.sentTime),
                        style: text.labelMedium!.copyWith(color: colors.textFaint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A report photo from memory or the asset bundle, or an empty frame.
class ReportPhotoThumb extends StatelessWidget {
  const ReportPhotoThumb({super.key, required this.photo, required this.width, required this.height});

  final ReportPhoto? photo;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.all(Radii.s),
        child: SizedBox(width: width, height: height, child: ReportPhotoImage(photo: photo)),
      );
}

/// The image itself, cover-fitted; an f-hole when there is none.
class ReportPhotoImage extends StatelessWidget {
  const ReportPhotoImage({super.key, required this.photo, this.fit = BoxFit.cover});

  final ReportPhoto? photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final empty = ColoredBox(
      color: colors.surfaceRaised,
      child: Center(
        child: LayoutBuilder(
          builder: (context, c) => FHole(
            height: (c.maxHeight.isFinite ? c.maxHeight : 96) * 0.5,
            color: colors.accent.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
    final p = photo;
    if (p == null) return empty;
    if (p.bytes != null) {
      return Image.memory(p.bytes!, fit: fit, errorBuilder: (_, _, _) => empty);
    }
    if (p.assetPath != null) {
      return Image.asset(p.assetPath!, fit: fit, errorBuilder: (_, _, _) => empty);
    }
    return empty;
  }
}

/// Italic serif for a renter's own words.
TextStyle quoteStyle(BuildContext context) =>
    AelosText.of(context).note.copyWith(color: AelosColors.of(context).text);
