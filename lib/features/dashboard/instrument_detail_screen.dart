import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/reading_value.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/instrument_data.dart';
import '../../data/instruments_notifier.dart';
import '../../data/sensor_session.dart';
import '../../domain/history/downsample.dart';
import '../../domain/history/gaps.dart';
import '../../domain/models/live_reading.dart';
import '../../domain/models/sensor_record.dart';
import '../../domain/thresholds/alert.dart';
import '../../sensor/sensor_connection.dart';

class InstrumentDetailScreen extends ConsumerStatefulWidget {
  const InstrumentDetailScreen({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  ConsumerState<InstrumentDetailScreen> createState() =>
      _InstrumentDetailScreenState();
}

class _InstrumentDetailScreenState
    extends ConsumerState<InstrumentDetailScreen> {
  _HistoryRange _range = _HistoryRange.week;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(instrumentProvider(widget.instrumentId));
    final session = ref.watch(sessionProvider);
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Instrument')),
        body: Center(
          child: CircularProgressIndicator(
            color: AelosColors.of(context).accent,
          ),
        ),
      );
    }

    final isConnected =
        session?.status == ConnectionStatus.connected ||
        session?.status == ConnectionStatus.syncing;
    final live = session?.instrumentId == widget.instrumentId && isConnected
        ? session?.live
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Condition history')),
      body: _DetailBody(
        data: data,
        live: live,
        range: _range,
        onRangeChanged: (range) => setState(() => _range = range),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.data,
    required this.live,
    required this.range,
    required this.onRangeChanged,
  });

  final InstrumentData data;
  final LiveReading? live;
  final _HistoryRange range;
  final ValueChanged<_HistoryRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final instrument = data.instrument;
    final latest = data.latestReading;
    final temperature = live?.celsius ?? latest?.celsius;
    final humidity = live?.humidity ?? latest?.humidity;
    final now = data.sensorNow;
    final start = now.subtract(range.duration);
    final visibleRecords = data.records
        .where((r) => !r.time.isBefore(start) && !r.time.isAfter(now))
        .toList();
    final buckets = downsampleReadings(visibleRecords, range.bucket);
    final gaps = findReadingGaps(visibleRecords)
        .where((gap) => !gap.end.isBefore(start) && !gap.start.isAfter(now))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math
            .min(constraints.maxWidth - Space.page * 2, 840.0)
            .toDouble();
        final horizontal = (constraints.maxWidth - maxWidth) / 2;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            Space.m,
            horizontal,
            Space.xxxl,
          ),
          child: Center(
            child: SizedBox(
              width: maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailPhoto(data: data),
                  const SizedBox(height: Space.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(
                              '${instrument.type.label} · ${instrument.dateLabel}',
                            ),
                            const SizedBox(height: Space.xs),
                            Text(instrument.name, style: text.displaySmall),
                            if (instrument.origin != null) ...[
                              const SizedBox(height: Space.xs),
                              Text(instrument.origin!, style: text.bodyMedium),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      StatusBadge(data.status, large: true),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  AelosCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Eyebrow('Current condition'),
                            const Spacer(),
                            if (live != null) ...[
                              Icon(
                                Icons.sensors_rounded,
                                size: 14,
                                color: colors.calm,
                              ),
                              const SizedBox(width: Space.xs),
                              Text(
                                'LIVE',
                                style: AelosText.of(context).eyebrow
                                    .copyWith(color: colors.calmInk),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: Space.l),
                        const Eyebrow('Relative humidity'),
                        const SizedBox(height: Space.xs),
                        if (humidity == null)
                          Text('—', style: AelosText.of(context).readingHero)
                        else
                          ReadingValue(
                            value: humidity,
                            unit: '%',
                            size: ReadingSize.hero,
                          ),
                        const SizedBox(height: Space.m),
                        const Hairline(),
                        const SizedBox(height: Space.m),
                        Row(
                          children: [
                            Icon(
                              Icons.thermostat_rounded,
                              size: 18,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: Space.s),
                            const Eyebrow('Temperature'),
                            const Spacer(),
                            if (temperature == null)
                              Text(
                                '—',
                                style: AelosText.of(context).readingSmall,
                              )
                            else
                              ReadingValue(
                                value: temperature,
                                unit: '°C',
                                size: ReadingSize.small,
                              ),
                          ],
                        ),
                        if (data.tighterLimitsReason != null) ...[
                          const SizedBox(height: Space.l),
                          const Hairline(),
                          const SizedBox(height: Space.m),
                          Text(
                            data.tighterLimitsReason!,
                            style: AelosText.of(context).note,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Eyebrow('Climate record'),
                            const SizedBox(height: Space.xs),
                            Text(
                              'Humidity over time',
                              style: text.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${data.records.length} signed records',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.m),
                  SegmentedButton<_HistoryRange>(
                    segments: const [
                      ButtonSegment(
                        value: _HistoryRange.day,
                        label: Text('24 h'),
                      ),
                      ButtonSegment(
                        value: _HistoryRange.week,
                        label: Text('7 days'),
                      ),
                      ButtonSegment(
                        value: _HistoryRange.month,
                        label: Text('30 days'),
                      ),
                    ],
                    selected: {range},
                    showSelectedIcon: false,
                    onSelectionChanged: (selected) =>
                        onRangeChanged(selected.single),
                  ),
                  const SizedBox(height: Space.m),
                  AelosCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: colors.calm.withValues(alpha: 0.55),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(width: Space.s),
                            Text(
                              'Preferred range · 40–60 %',
                              style: text.bodySmall,
                            ),
                            const Spacer(),
                            Container(
                              width: 16,
                              height: 2,
                              color: colors.accent,
                            ),
                            const SizedBox(width: Space.xs),
                            Text('RH', style: text.bodySmall),
                          ],
                        ),
                        const SizedBox(height: Space.m),
                        SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _HumidityChartPainter(
                              buckets: buckets,
                              gaps: gaps,
                              start: start,
                              end: now,
                              colors: colors,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 42,
                            right: Space.s,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(range.agoLabel, style: text.bodySmall),
                              Text(
                                'NOW',
                                style: AelosText.of(context).eyebrow
                                    .copyWith(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  _EventTimeline(data: data),
                  const SizedBox(height: Space.xxl),
                  AelosCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Instrument record'),
                        const SizedBox(height: Space.m),
                        Text(
                          '${instrument.topWood} top · ${instrument.backWood} back · ${instrument.varnish}',
                          style: text.bodyMedium,
                        ),
                        if (instrument.maker != null) ...[
                          const SizedBox(height: Space.s),
                          Text(instrument.maker!, style: text.bodySmall),
                        ],
                        if (instrument.crackRepairNote != null) ...[
                          const SizedBox(height: Space.m),
                          const Hairline(),
                          const SizedBox(height: Space.m),
                          Text(
                            instrument.crackRepairNote!,
                            style: AelosText.of(context).note,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailPhoto extends StatelessWidget {
  const _DetailPhoto({required this.data});

  final InstrumentData data;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final photo = data.instrument.photo;
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radii.l),
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Hero(
          tag: 'instrument-photo-${data.id}',
          child: data.photoBytes != null
              ? Image.memory(
                  data.photoBytes!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(color: colors.surface),
                )
              : photo == null
              ? ColoredBox(color: colors.surface)
              : Image.asset(
                  photo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(color: colors.surface),
                ),
        ),
      ),
    );
  }
}

enum _HistoryRange {
  day,
  week,
  month;

  Duration get duration => switch (this) {
    day => const Duration(hours: 24),
    week => const Duration(days: 7),
    month => const Duration(days: 30),
  };

  Duration get bucket => switch (this) {
    day => const Duration(minutes: 20),
    week => const Duration(hours: 2),
    month => const Duration(hours: 6),
  };

  String get agoLabel => switch (this) {
    day => '24 HOURS AGO',
    week => '7 DAYS AGO',
    month => '30 DAYS AGO',
  };
}

class _HumidityChartPainter extends CustomPainter {
  const _HumidityChartPainter({
    required this.buckets,
    required this.gaps,
    required this.start,
    required this.end,
    required this.colors,
  });

  final List<ReadingBucket> buckets;
  final List<ReadingGap> gaps;
  final DateTime start;
  final DateTime end;
  final AelosColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 39.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 8.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final spanMs = math.max(1, end.difference(start).inMilliseconds);
    double xFor(DateTime time) =>
        plot.left +
        (time.difference(start).inMilliseconds / spanMs)
                .clamp(0.0, 1.0)
                .toDouble() *
            plot.width;
    double yFor(double tenths) {
      final clamped = tenths.clamp(300.0, 700.0).toDouble();
      return plot.bottom - ((clamped - 300) / 400) * plot.height;
    }

    final band = Rect.fromLTRB(plot.left, yFor(600), plot.right, yFor(400));
    canvas.drawRect(band, Paint()..color = colors.calm.withValues(alpha: 0.12));

    for (final gap in gaps) {
      final x1 = xFor(gap.start);
      final x2 = xFor(gap.end);
      if (x2 - x1 < 2) continue;
      final rect = Rect.fromLTRB(x1, plot.top, x2, plot.bottom);
      canvas.drawRect(
        rect,
        Paint()..color = colors.attention.withValues(alpha: 0.07),
      );
      canvas.save();
      canvas.clipRect(rect);
      final hatch = Paint()
        ..color = colors.attention.withValues(alpha: 0.28)
        ..strokeWidth = 0.8;
      for (var x = rect.left - plot.height; x < rect.right; x += 9) {
        canvas.drawLine(
          Offset(x, plot.bottom),
          Offset(x + plot.height, plot.top),
          hatch,
        );
      }
      canvas.restore();
    }

    final labelStyle = TextStyle(
      color: colors.textFaint,
      fontFamily: Fonts.sans,
      fontSize: 10,
    );
    for (final tenths in [600, 500, 400]) {
      final y = yFor(tenths.toDouble());
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..color = colors.hairline
          ..strokeWidth = 0.7,
      );
      final label = TextPainter(
        text: TextSpan(text: '${tenths ~/ 10}', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - label.height / 2));
    }

    if (buckets.isEmpty) {
      final empty = TextPainter(
        text: TextSpan(
          text: 'No readings in this period',
          style: labelStyle.copyWith(fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: plot.width);
      empty.paint(
        canvas,
        Offset(
          plot.center.dx - empty.width / 2,
          plot.center.dy - empty.height / 2,
        ),
      );
      return;
    }

    final linePaint = Paint()
      ..color = colors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    Offset? previous;
    DateTime? previousTime;
    for (final bucket in buckets) {
      final point = Offset(xFor(bucket.start), yFor(bucket.meanTenthsHumidity));
      final crossesGap =
          previousTime != null &&
          gaps.any(
            (gap) =>
                gap.start.isBefore(bucket.start) &&
                gap.end.isAfter(previousTime!),
          );
      if (previous != null && !crossesGap) {
        canvas.drawLine(previous, point, linePaint);
      }
      previous = point;
      previousTime = bucket.start;
    }
    if (previous != null) {
      canvas.drawCircle(
        previous,
        3.2,
        Paint()
          ..color = colors.surfaceRaised
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(previous, 2.2, Paint()..color = colors.accent);
    }
  }

  @override
  bool shouldRepaint(_HumidityChartPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.gaps != gaps ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.colors != colors;
}

class _EventTimeline extends StatelessWidget {
  const _EventTimeline({required this.data});

  final InstrumentData data;

  @override
  Widget build(BuildContext context) {
    final entries = _entries(data);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Signed condition history'),
        const SizedBox(height: Space.xs),
        Text('Events and alerts', style: text.headlineMedium),
        const SizedBox(height: Space.m),
        if (entries.isEmpty)
          AelosCard(
            child: Text(
              'No notable events in the signed history.',
              style: text.bodyMedium,
            ),
          )
        else
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: Space.s),
            _TimelineCard(entry: entries[i], data: data),
          ],
      ],
    );
  }

  List<_TimelineEntry> _entries(InstrumentData data) {
    final alertBySequence = <int, Alert>{};
    for (final alert in data.alerts) {
      for (final seq in alert.seqs) {
        alertBySequence[seq] = alert;
      }
    }
    final representedAlerts = <Alert>{};
    final entries = <_TimelineEntry>[];
    for (final record in data.records.reversed) {
      if (record.kind == RecordKind.reading) continue;
      final alert = alertBySequence[record.seq];
      if (alert != null) representedAlerts.add(alert);
      entries.add(
        _TimelineEntry(
          time: record.time,
          icon: switch (record.kind) {
            RecordKind.impact => Icons.flash_on_rounded,
            RecordKind.freeFall => Icons.south_rounded,
            RecordKind.boot => Icons.power_settings_new_rounded,
            RecordKind.reading => Icons.water_drop_outlined,
          },
          title: switch (record.kind) {
            RecordKind.impact =>
              'Impact recorded · ${record.peakG?.toStringAsFixed(1) ?? '—'} g',
            RecordKind.freeFall =>
              'Free fall recorded · ${record.freeFallMs ?? 0} ms',
            RecordKind.boot => 'Sensor restarted',
            RecordKind.reading => '',
          },
          detail: alert?.why ?? 'Signed event recorded by the sensor.',
          alert: alert,
        ),
      );
    }
    for (final alert in data.alerts) {
      if (representedAlerts.contains(alert)) continue;
      entries.add(
        _TimelineEntry(
          time: alert.time,
          icon: alert.title.toLowerCase().contains('temperature')
              ? Icons.thermostat_rounded
              : Icons.water_drop_outlined,
          title: alert.title,
          detail: alert.why,
          alert: alert,
        ),
      );
    }
    entries.sort((a, b) => b.time.compareTo(a.time));
    return entries.take(8).toList();
  }
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.time,
    required this.icon,
    required this.title,
    required this.detail,
    required this.alert,
  });

  final DateTime time;
  final IconData icon;
  final String title;
  final String detail;
  final Alert? alert;
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entry, required this.data});

  final _TimelineEntry entry;
  final InstrumentData data;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final statusColor = entry.alert == null
        ? colors.textMuted
        : colors.status(entry.alert!.severity);
    return AelosCard(
      padding: const EdgeInsets.all(Space.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(entry.icon, size: 17, color: statusColor),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(entry.title, style: text.titleSmall)),
                    if (entry.alert != null) ...[
                      const SizedBox(width: Space.s),
                      StatusBadge(entry.alert!.severity),
                    ],
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(entry.detail, style: text.bodySmall),
                const SizedBox(height: Space.s),
                Text(
                  _dateTime(data.displayTime(entry.time)),
                  style: text.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _dateTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year} · $hour:$minute';
}
