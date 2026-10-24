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
import '../../domain/models/sensor_record.dart';
import '../dashboard/instrument_detail_screen.dart';
import 'alerts_tab.dart';
import 'luthier_fleet.dart';
import 'luthier_format.dart';
import 'luthier_widgets.dart';
import 'rental_panel.dart';
import 'report_review_screen.dart';
import 'reports_tab.dart';

/// One fleet instrument from the workshop's side: condition at a glance, the
/// rental, its alerts and reports. The full climate record is the shared
/// [InstrumentDetailScreen].
class FleetInstrumentScreen extends ConsumerWidget {
  const FleetInstrumentScreen({super.key, required this.instrumentId});

  final String instrumentId;

  static Future<void> open(BuildContext context, String instrumentId) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => FleetInstrumentScreen(instrumentId: instrumentId)),
      );

  void _openHistory(BuildContext context) => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => InstrumentDetailScreen(instrumentId: instrumentId)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(fleetProvider).where((e) => e.id == instrumentId).firstOrNull;
    final colors = AelosColors.of(context);
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: CircularProgressIndicator(color: colors.accent)),
      );
    }
    final alerts = [
      for (final a in ref.watch(fleetAlertsProvider))
        if (a.entry.id == instrumentId) a,
    ];
    final reports = [
      for (final r in ref.watch(fleetReportsProvider))
        if (r.report.instrumentId == instrumentId) r,
    ];
    final isLive = ref.watch(liveFleetIdProvider) == instrumentId;
    final live = isLive ? ref.watch(sessionProvider)?.live : null;

    var i = 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('In your care'),
        actions: [
          IconButton(
            tooltip: 'Condition history',
            icon: const Icon(Icons.timeline_rounded),
            onPressed: () => _openHistory(context),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: LuthierPage(
        children: [
          _Hero(entry: entry).riseIn(i++),
          const SizedBox(height: Space.l),
          _Condition(
            entry: entry,
            live: isLive,
            humidity: live?.humidity,
            celsius: live?.celsius,
          ).riseIn(i++),
          const SizedBox(height: Space.m),
          _HistoryLink(entry: entry, onTap: () => _openHistory(context)).riseIn(i++),
          const SizedBox(height: Space.xxl),
          const SectionHeader('Rental', ornament: true).riseIn(i++),
          RentalPanel(entry: entry).riseIn(i++),
          const SizedBox(height: Space.xxl),
          SectionHeader('Alerts', count: alerts.length).riseIn(i++),
          if (alerts.isEmpty) const LuthierEmpty('No alerts in this history. A calm record.'),
          for (final a in alerts.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: FleetAlertTile(alert: a, showInstrument: false),
            ).riseIn(i++),
          if (reports.isNotEmpty) ...[
            const SizedBox(height: Space.xl),
            SectionHeader('Reports', count: reports.length).riseIn(i++),
            for (final r in reports)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.m),
                child: ReportCard(
                  report: r,
                  onTap: () => ReportReviewScreen.open(context, r.report.id),
                ),
              ).riseIn(i++),
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.entry});

  final FleetEntry entry;

  @override
  Widget build(BuildContext context) {
    final instrument = entry.data.instrument;
    final text = Theme.of(context).textTheme;
    return Hero(
      tag: 'fleet-photo-${entry.id}',
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radii.l),
        child: AspectRatio(
          aspectRatio: 1.55,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InstrumentThumb(data: entry.data, width: double.infinity, height: double.infinity),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD0000000)],
                    stops: [0.38, 1],
                  ),
                ),
              ),
              Positioned(
                left: Space.l + 2,
                right: Space.l + 2,
                bottom: Space.l,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${instrument.type.label} · ${instrument.dateLabel}'.toUpperCase(),
                      style: AelosText.of(context).eyebrow.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      instrument.name,
                      style: text.headlineLarge!.copyWith(color: Colors.white),
                    ),
                    if (instrument.origin != null)
                      Text(
                        instrument.origin!,
                        style: text.bodySmall!.copyWith(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Condition extends StatelessWidget {
  const _Condition({required this.entry, required this.live, this.humidity, this.celsius});

  final FleetEntry entry;
  final bool live;
  final double? humidity;
  final double? celsius;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final data = entry.data;
    final latest = data.latestReading;
    final h = humidity ?? latest?.humidity;
    final t = celsius ?? latest?.celsius;
    return AelosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(entry.status, large: true),
              const Spacer(),
              if (live)
                const LiveMark()
              else if (latest != null)
                Text(
                  'Synced ${LuthierFormat.ago(data.displayTime(latest.time))}',
                  style: text.labelMedium!.copyWith(color: colors.textFaint),
                ),
            ],
          ),
          const SizedBox(height: Space.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Reading(label: 'Humidity', value: h, unit: '%')),
              Container(width: 0.8, height: 58, color: colors.hairline),
              const SizedBox(width: Space.l),
              Expanded(child: _Reading(label: 'Temperature', value: t, unit: '°C')),
            ],
          ),
          if (data.tighterLimitsReason != null) ...[
            const SizedBox(height: Space.l),
            const Hairline(),
            const SizedBox(height: Space.m),
            Text(data.tighterLimitsReason!, style: AelosText.of(context).note),
          ],
        ],
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.label, required this.value, required this.unit});

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: Space.xs),
          if (value == null)
            Text('—', style: AelosText.of(context).readingLarge)
          else
            ReadingValue(value: value!, unit: unit),
        ],
      );
}

class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.entry, required this.onTap});

  final FleetEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final records = entry.data.records;
    final days = records.isEmpty
        ? 0
        : records.last.time.difference(records.first.time).inHours / 24;
    final impacts = records.where((r) => r.kind == RecordKind.impact).length;
    final n = records.length.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => ',',
        );
    return AelosCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m + 2),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: colors.accent, size: 22),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed condition history', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '$n records · ${days.round()} days'
                  '${impacts == 0 ? '' : ' · $impacts ${impacts == 1 ? 'impact' : 'impacts'}'}',
                  style: text.bodySmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textFaint),
        ],
      ),
    );
  }
}
