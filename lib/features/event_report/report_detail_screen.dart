import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_theme.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/rise_in.dart';
import '../../data/accounts.dart';
import '../../data/instrument_data.dart';
import '../../data/instruments_notifier.dart';
import '../../domain/models/event_report.dart';
import '../../domain/models/instrument.dart';
import 'explanation_step.dart';
import 'instrument_drawing.dart';
import 'report_copy.dart';
import 'report_photo_image.dart';

/// One submitted report, live from `eventReportsProvider` so status changes
/// show at once. [actionsBuilder] adds a pinned footer, e.g. the luthier's
/// status actions.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.reportId, this.actionsBuilder});

  final String reportId;
  final Widget Function(BuildContext context, EventReport report)? actionsBuilder;

  static Route<void> route(String reportId, {Widget Function(BuildContext, EventReport)? actionsBuilder}) =>
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(reportId: reportId, actionsBuilder: actionsBuilder),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(eventReportsProvider).where((r) => r.id == reportId).firstOrNull;
    final data = report == null ? null : ref.watch(instrumentProvider(report.instrumentId));
    final colors = AelosColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Event report')),
      body: report == null
          ? Center(child: Text('This report is no longer here.', style: AelosText.of(context).note))
          : ReportView(report: report, data: data),
      bottomNavigationBar: report == null || actionsBuilder == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(top: BorderSide(color: colors.hairline, width: 0.8)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, Space.m),
                  child: actionsBuilder!(context, report),
                ),
              ),
            ),
    );
  }
}

/// The body of a report, scrollable: photos, the event, status, the
/// account in the author's words, and who it went to.
class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.report, this.data});

  final EventReport report;

  /// For display times and the instrument's name and type.
  final InstrumentData? data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AelosColors.of(context);
    final data = this.data;
    DateTime shown(DateTime signed) => data?.displayTime(signed) ?? signed.toLocal();
    final luthier = DemoDirectory.luthierById(report.luthierId);
    final event = EventSummary(
      title: report.eventTitle,
      when: formatWhen(shown(report.eventTime)),
      instrumentName: data?.instrument.name ?? 'Instrument',
      seq: report.eventSeq,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PhotoCarousel(report: report, type: data?.instrument.type ?? InstrumentType.violin).riseIn(0),
              const SizedBox(height: Space.xl),
              EventSummaryCard(event: event, compact: true).riseIn(1),
              if (luthier != null) ...[
                const SizedBox(height: Space.xl),
                const Eyebrow('Status').riseIn(2),
                const SizedBox(height: Space.m),
                ReportStatusTrack(status: report.status).riseIn(2),
              ],
              if (report.luthierNote case final note?) ...[
                const SizedBox(height: Space.l),
                AelosCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('From ${luthier?.master ?? 'the luthier'}', color: colors.accentInk),
                      const SizedBox(height: Space.s),
                      Text(note, style: AelosText.of(context).note.copyWith(color: colors.text)),
                    ],
                  ),
                ).riseIn(3),
              ],
              const SizedBox(height: Space.xxl),
              Eyebrow('In ${report.authorName.split(' ').first}’s words').riseIn(3),
              const SizedBox(height: Space.m),
              if (report.causes.isNotEmpty) ...[
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [for (final c in report.causes) CauseChip(label: c, selected: true)],
                ).riseIn(4),
                const SizedBox(height: Space.m),
              ],
              Text(
                report.explanation.isEmpty ? 'No notes added.' : report.explanation,
                style: report.explanation.isEmpty
                    ? AelosText.of(context).note
                    : text.titleLarge!.copyWith(fontWeight: FontWeight.w400, height: 1.4),
              ).riseIn(4),
              const SizedBox(height: Space.xl),
              const Hairline(ornament: true, indent: Space.xxl).riseIn(5),
              const SizedBox(height: Space.xl),
              _Meta(
                label: 'Documented by',
                value: '${report.authorName} · ${formatWhen(shown(report.createdAt))}',
              ).riseIn(5),
              const SizedBox(height: Space.m),
              _Meta(
                label: luthier == null ? 'Kept in' : 'Sent to',
                value: luthier == null
                    ? 'The condition history'
                    : '${luthier.workshop} · ${luthier.master}, ${luthier.city}',
              ).riseIn(6),
              const SizedBox(height: Space.xl),
              Text(
                'Notes and photos come from ${report.authorName}. The sensor signs its '
                'measurements; this account sits beside them, unsigned.',
                style: text.bodySmall!.copyWith(color: colors.textFaint),
              ).riseIn(7),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        const SizedBox(height: Space.xs),
        Text(value, style: text.bodyMedium),
      ],
    );
  }
}

/// Sent → Reviewed → Inspection scheduled → Resolved, with the current
/// stage named (icon and word, never colour alone).
class ReportStatusTrack extends StatelessWidget {
  const ReportStatusTrack({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final current = status.index;
    final done = status == ReportStatus.resolved;
    final mark = done ? colors.calm : colors.accent;
    return AelosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status.icon, size: 20, color: mark),
              const SizedBox(width: Space.s),
              Text(status.label, style: text.titleMedium!.copyWith(color: done ? colors.calmInk : colors.text)),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in ReportStatus.values) ...[
                if (s.index > 0) const SizedBox(width: Space.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: s.index == current ? 2 : 1.4,
                        decoration: BoxDecoration(
                          color: s.index <= current ? mark : colors.hairline,
                          borderRadius: const BorderRadius.all(Radii.pill),
                        ),
                      ),
                      const SizedBox(height: Space.xs + 2),
                      Text(
                        s.label,
                        maxLines: 2,
                        style: text.labelSmall!.copyWith(
                          letterSpacing: 0.2,
                          fontWeight: s.index == current ? FontWeight.w600 : FontWeight.w500,
                          color: s.index <= current ? colors.text : colors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.report, required this.type});

  final EventReport report;
  final InstrumentType type;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  late final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final photos = widget.report.photos;
    const radius = BorderRadius.all(Radii.l);
    if (photos.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: radius,
          border: Border.all(color: colors.hairline, width: 0.8),
        ),
        padding: const EdgeInsets.all(Space.xl),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: CustomPaint(
                painter: InstrumentDrawingPainter(
                  type: widget.type,
                  angle: PhotoAngle.front,
                  ink: colors.textFaint,
                  detail: colors.hairline,
                ),
                size: Size.infinite,
              ),
            ),
            const SizedBox(width: Space.xl),
            Expanded(child: Text('No photos with this report.', style: AelosText.of(context).note)),
          ],
        ),
      );
    }
    final label = AelosText.of(context).eyebrow.copyWith(color: AelosPalette.ivory);
    return Column(
      children: [
        ClipRRect(
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => Navigator.of(context).push(ReportPhotoGallery.route(photos, initial: i)),
                    child: Hero(
                      tag: _heroTag(photos[i]),
                      child: ReportPhotoImage(photos[i]),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.65, 1],
                        colors: [
                          AelosPalette.walnutDeep.withValues(alpha: 0),
                          AelosPalette.walnutDeep.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: Space.l,
                  bottom: Space.l,
                  child: AnimatedSwitcher(
                    duration: Motion.fast,
                    child: Text(photos[_page].angle.short.toUpperCase(), key: ValueKey(_page), style: label),
                  ),
                ),
                Positioned(
                  right: Space.l,
                  bottom: Space.l,
                  child: Row(
                    children: [
                      Text('${_page + 1} / ${photos.length}', style: label),
                      const SizedBox(width: Space.s),
                      const Icon(Icons.open_in_full_rounded, size: 14, color: AelosPalette.ivory),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: Space.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < photos.length; i++)
                AnimatedContainer(
                  duration: Motion.medium,
                  curve: Motion.enter,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 2,
                  color: i == _page ? colors.accent : colors.hairline,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

Object _heroTag(ReportPhoto photo) => ('report-photo', photo);

/// Photos full screen on walnut, swipeable and zoomable, whatever the theme.
class ReportPhotoGallery extends StatefulWidget {
  const ReportPhotoGallery({super.key, required this.photos, this.initial = 0});

  final List<ReportPhoto> photos;
  final int initial;

  static Route<void> route(List<ReportPhoto> photos, {int initial = 0}) => PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: Motion.medium,
        reverseTransitionDuration: Motion.medium,
        pageBuilder: (_, _, _) => ReportPhotoGallery(photos: photos, initial: initial),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Motion.enter), child: child),
      );

  @override
  State<ReportPhotoGallery> createState() => _ReportPhotoGalleryState();
}

class _ReportPhotoGalleryState extends State<ReportPhotoGallery> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Theme(
      data: AelosTheme.dark,
      child: Builder(
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return Scaffold(
            backgroundColor: AelosPalette.walnutDeep,
            body: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: photos.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => InteractiveViewer(
                    maxScale: 4,
                    child: Center(
                      child: Hero(
                        tag: _heroTag(photos[i]),
                        child: ReportPhotoImage(photos[i], fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: AelosPalette.ivory),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            Eyebrow(photos[_page].angle.short),
                            Text('${_page + 1} of ${photos.length}', style: text.labelMedium),
                          ],
                        ),
                        const Spacer(),
                        const SizedBox(width: kMinInteractiveDimension),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A documented report as an entry in an instrument's history: the first
/// photo, the event and an excerpt of the account.
class ReportHistoryCard extends StatelessWidget {
  const ReportHistoryCard({super.key, required this.report, required this.when, required this.onTap});

  final EventReport report;

  /// Formatted display time of the report.
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final cover = report.photos.firstOrNull;
    final luthier = DemoDirectory.luthierById(report.luthierId);
    final headline = splitEventTitle(report.eventTitle).headline;
    final excerpt = report.explanation.isNotEmpty ? report.explanation : report.causes.join(' · ');
    return AelosCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(Radii.s),
            child: SizedBox(
              width: 56,
              height: 70,
              child: cover == null
                  ? ColoredBox(
                      color: colors.background,
                      child: Icon(Icons.history_edu_outlined, size: 20, color: colors.textFaint),
                    )
                  : ReportPhotoImage(cover, cacheWidth: 200),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Documented · ${report.photos.length} photos', color: colors.accentInk),
                const SizedBox(height: Space.xs),
                Text(headline, style: text.titleSmall),
                if (excerpt.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
                const SizedBox(height: Space.s),
                Row(
                  children: [
                    Icon(report.status.icon, size: 14, color: colors.textMuted),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(
                        luthier == null ? 'In your condition history' : '${report.status.label} · ${luthier.workshop}',
                        style: text.labelMedium!.copyWith(color: colors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(when, style: text.labelMedium),
              ],
            ),
          ),
          const SizedBox(width: Space.xs),
          Icon(Icons.chevron_right_rounded, size: 20, color: colors.textFaint),
        ],
      ),
    );
  }
}
