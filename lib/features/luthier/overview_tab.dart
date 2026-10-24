import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/reading_value.dart';
import '../../core/widgets/rise_in.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/sensor_session.dart';
import '../../domain/models/condition_status.dart';
import '../../domain/models/event_report.dart';
import 'fleet_instrument_screen.dart';
import 'luthier_fleet.dart';
import 'luthier_format.dart';
import 'luthier_widgets.dart';
import 'report_review_screen.dart';

/// Workshop header, the day's numbers, what needs attention, then the fleet.
class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.onShowFleet, required this.onShowReports});

  final VoidCallback onShowFleet;
  final VoidCallback onShowReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workshop = ref.watch(workshopProvider);
    final fleet = ref.watch(fleetProvider);
    final attention = ref.watch(attentionProvider);
    final reports = ref.watch(fleetReportsProvider);
    final liveId = ref.watch(liveFleetIdProvider);
    final live = ref.watch(sessionProvider)?.live;

    final out = fleet.where((e) => !e.inWorkshop).length;
    final needing = fleet.where((e) => e.status != ConditionStatus.calm).length;
    final toReview = reports.where((r) => r.needsReview).length;
    final firstName = workshop?.master.split(' ').first ?? '';

    var i = 0;
    return LuthierPage(
      children: [
        PageHeading(
          eyebrow: '${_greeting()}, $firstName',
          title: workshop?.workshop ?? 'The workshop',
          subtitle: '${workshop?.city ?? ''} · ${_count(fleet.length)} '
              '${fleet.length == 1 ? 'instrument' : 'instruments'} in your care',
        ).riseIn(i++),
        const SizedBox(height: Space.xl),
        _SummaryRow(
          out: out,
          inWorkshop: fleet.length - out,
          needing: needing,
          toReview: toReview,
          onTapOut: onShowFleet,
          onTapReports: onShowReports,
        ).riseIn(i++),
        const SizedBox(height: Space.xxl),
        SectionHeader('Needs your attention', count: attention.length).riseIn(i++),
        if (attention.isEmpty)
          const LuthierEmpty('Every instrument is calm, and no reports are waiting.').riseIn(i++),
        for (final item in attention)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.m),
            child: switch (item) {
              InstrumentAttention(:final entry) => _InstrumentAttentionCard(
                  entry: entry,
                  onTap: () => FleetInstrumentScreen.open(context, entry.id),
                ),
              ReportAttention(:final report) => _ReportAttentionCard(
                  report: report,
                  onTap: () => ReportReviewScreen.open(context, report.report.id),
                ),
            },
          ).riseIn(i++),
        const SizedBox(height: Space.xl),
        SectionHeader('The fleet', count: fleet.length).riseIn(i++),
        for (final entry in fleet)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.m),
            child: FleetCard(
              entry: entry,
              live: entry.id == liveId,
              liveHumidity: entry.id == liveId ? live?.humidity : null,
              onTap: () => FleetInstrumentScreen.open(context, entry.id),
            ),
          ).riseIn(i++),
        const SizedBox(height: Space.xl),
        Text(
          'Each instrument keeps its own signed condition history, whoever has it.',
          style: AelosText.of(context).note,
        ).riseIn(i++),
      ],
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : h < 18
            ? 'Good afternoon'
            : 'Good evening';
  }
}

String _count(int n) => const [
      'No', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
    ].elementAtOrNull(n) ?? '$n';

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.out,
    required this.inWorkshop,
    required this.needing,
    required this.toReview,
    required this.onTapOut,
    required this.onTapReports,
  });

  final int out;
  final int inWorkshop;
  final int needing;
  final int toReview;
  final VoidCallback onTapOut;
  final VoidCallback onTapReports;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final figures = [
      _Figure(value: out, label: 'Rented\nout', onTap: onTapOut),
      _Figure(value: inWorkshop, label: 'In the\nworkshop', onTap: onTapOut),
      _Figure(
        value: needing,
        label: 'Need\nattention',
        color: needing > 0 ? colors.attentionInk : null,
        icon: needing > 0 ? ConditionStatus.attention.icon : null,
        iconColor: colors.attention,
      ),
      _Figure(
        value: toReview,
        label: 'Reports\nto review',
        color: toReview > 0 ? colors.accentInk : null,
        onTap: onTapReports,
      ),
    ];
    Widget divider() => Container(width: 0.8, height: 44, color: colors.hairline);
    Widget row(List<Widget> items) => IntrinsicHeight(
          child: Row(
            children: [
              for (final (n, f) in items.indexed) ...[
                if (n > 0) divider(),
                Expanded(child: f),
              ],
            ],
          ),
        );
    return AelosCard(
      padding: const EdgeInsets.symmetric(vertical: Space.l),
      // Four across from about 380 dp; two by two on narrower phones.
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 340
            ? row(figures)
            : Column(
                children: [
                  row(figures.sublist(0, 2)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.m, horizontal: Space.l),
                    child: Container(height: 0.8, color: colors.hairline),
                  ),
                  row(figures.sublist(2)),
                ],
              ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    this.color,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  final int value;
  final String label;
  final Color? color;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                '$value',
                style: AelosText.of(context)
                    .readingLarge
                    .copyWith(fontSize: text.displaySmall!.fontSize, color: color),
              ),
                  if (icon != null) ...[
                    const SizedBox(width: Space.xs),
                    Icon(icon, size: 15, color: iconColor),
                  ],
                ],
              ),
              const SizedBox(height: Space.s),
              Text(label, style: text.labelMedium!.copyWith(height: 1.3)),
            ],
          ),
      ),
    );
  }
}

/// An instrument that is not calm: why, and what to do.
class _InstrumentAttentionCard extends StatelessWidget {
  const _InstrumentAttentionCard({required this.entry, required this.onTap});

  final FleetEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final alert = entry.latestAlert;
    final rental = entry.rental;
    return AelosCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: colors.status(entry.status)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Space.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InstrumentThumb(data: entry.data, width: 44, height: 52),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.data.instrument.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleLarge,
                              ),
                              Text(
                                rental.inWorkshop ? 'In the workshop' : 'With ${rental.renterName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.m),
                    const Hairline(),
                    const SizedBox(height: Space.m),
                    Row(
                      children: [
                        StatusBadge(entry.status),
                        const Spacer(),
                        if (entry.data.latestReading?.humidity case final h?)
                          ReadingValue(value: h, unit: '% RH', size: ReadingSize.small),
                      ],
                    ),
                    if (alert != null) ...[
                      const SizedBox(height: Space.m),
                      Text(alert.title, style: text.titleSmall!.copyWith(color: colors.statusInk(alert.severity))),
                      const SizedBox(height: 2),
                      Text(alert.why, style: text.bodyMedium),
                      const SizedBox(height: Space.s),
                      Text(alert.whatToDo, style: text.bodySmall),
                      const SizedBox(height: Space.m),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: colors.textFaint),
                          const SizedBox(width: Space.xs),
                          Expanded(
                            child: Text(
                              LuthierFormat.when(entry.data.displayTime(alert.time)),
                              style: text.labelMedium!.copyWith(color: colors.textFaint),
                            ),
                          ),
                          Text('Open', style: text.labelLarge!.copyWith(color: colors.accentInk)),
                          Icon(Icons.chevron_right_rounded, size: 18, color: colors.accentInk),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A renter's report that hasn't been reviewed yet.
class _ReportAttentionCard extends StatelessWidget {
  const _ReportAttentionCard({required this.report, required this.onTap});

  final FleetReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final r = report.report;
    final photos = r.photos.length;
    return AelosCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: colors.accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Space.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Eyebrow('New report · ${r.authorName}', color: colors.accentInk)),
                        const ReportStatusPill(ReportStatus.submitted),
                      ],
                    ),
                    const SizedBox(height: Space.s),
                    Text(r.eventTitle, style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      report.entry?.data.instrument.name ?? r.instrumentId,
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: Space.m),
                    Text(
                      '“${r.explanation}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AelosText.of(context).note.copyWith(fontSize: text.bodyLarge!.fontSize),
                    ),
                    const SizedBox(height: Space.m),
                    Row(
                      children: [
                        Icon(Icons.photo_library_outlined, size: 14, color: colors.textFaint),
                        const SizedBox(width: Space.xs),
                        Expanded(
                          child: Text(
                            '$photos ${photos == 1 ? 'photo' : 'photos'} · sent ${LuthierFormat.ago(report.sentTime)}',
                            style: text.labelMedium!.copyWith(color: colors.textFaint),
                          ),
                        ),
                        Text('Review', style: text.labelLarge!.copyWith(color: colors.accentInk)),
                        Icon(Icons.chevron_right_rounded, size: 18, color: colors.accentInk),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
