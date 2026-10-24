import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/theme_mode.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/f_hole.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/reading_value.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/accounts.dart';
import '../../data/instrument_data.dart';
import '../../data/instruments_notifier.dart';
import '../../data/sensor_session.dart';
import '../../domain/models/condition_status.dart';
import '../../domain/models/live_reading.dart';
import '../../domain/models/sensor_record.dart';
import '../../sensor/sensor_connection.dart';
import '../demo_panel/demo_panel.dart';
import '../passport/passport_verify_screen.dart';
import '../register/registration_flow.dart';
import '../style_guide/style_guide_screen.dart';
import 'instrument_detail_screen.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  void _openStyleGuide() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const StyleGuideScreen()),
    );
  }

  void _openDemoPanel() {
    unawaited(showDemoPanel(context, onOpenStyleGuide: _openStyleGuide));
  }

  void _openRegistration() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RegistrationFlow(
          showOnboarding: !ref.read(onboardingCompletedProvider),
        ),
      ),
    );
  }

  void _openPassportVerification() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PassportVerifyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instruments = ref.watch(instrumentsProvider);
    final session = ref.watch(sessionProvider);
    final awaySummary = ref.watch(awaySummaryProvider);
    final colors = AelosColors.of(context);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _openDemoPanel,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FHole(height: 27, color: colors.accent),
                    const SizedBox(width: Space.s),
                    const Text('Aelos'),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Verify a condition passport',
            icon: const Icon(Icons.verified_outlined),
            onPressed: _openPassportVerification,
          ),
          IconButton(
            tooltip: 'Add an instrument',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openRegistration,
          ),
          IconButton(
            tooltip: 'Design system preview',
            icon: const Icon(Icons.palette_outlined),
            onPressed: _openStyleGuide,
          ),
          IconButton(
            tooltip: 'Switch light and dark',
            icon: Icon(
              brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () =>
                ref.read(themeModeProvider.notifier).toggle(brightness),
          ),
          const SizedBox(width: Space.s),
        ],
      ),
      body: instruments.when(
        data: (_) => _DashboardBody(
          instruments: ref.watch(visibleInstrumentsProvider),
          session: session,
          awaySummary: awaySummary,
          startupError: null,
          onDismissAwaySummary: ref.read(awaySummaryProvider.notifier).dismiss,
          onAddInstrument: _openRegistration,
        ),
        error: (error, _) => _LoadFailure(error: error.toString()),
        loading: () => const _LoadingState(),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.instruments,
    required this.session,
    required this.awaySummary,
    required this.startupError,
    required this.onDismissAwaySummary,
    required this.onAddInstrument,
  });

  final List<InstrumentData> instruments;
  final SessionState? session;
  final AwaySummary? awaySummary;
  final String? startupError;
  final VoidCallback onDismissAwaySummary;
  final VoidCallback onAddInstrument;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final activeInstrument = instruments
        .where((item) => item.id == session?.instrumentId)
        .firstOrNull;
    final liveSession =
        session?.status == ConnectionStatus.connected ||
        session?.status == ConnectionStatus.syncing;
    final String sensorLabel;
    final IconData sensorIcon;
    final Color sensorColor;

    if (startupError != null) {
      sensorLabel = 'Demo sensor unavailable';
      sensorIcon = Icons.sensors_off_rounded;
      sensorColor = colors.attention;
    } else if (session?.status == ConnectionStatus.connected) {
      sensorLabel = 'Mock sensor connected';
      sensorIcon = Icons.bluetooth_connected_rounded;
      sensorColor = colors.calm;
    } else if (session?.status == ConnectionStatus.syncing) {
      sensorLabel = 'Syncing signed history';
      sensorIcon = Icons.sync_rounded;
      sensorColor = colors.accent;
    } else if (session?.status == ConnectionStatus.disconnected) {
      sensorLabel = 'Mock sensor disconnected';
      sensorIcon = Icons.bluetooth_disabled_rounded;
      sensorColor = colors.attention;
    } else {
      sensorLabel = 'Connecting to the mock sensor';
      sensorIcon = Icons.bluetooth_searching_rounded;
      sensorColor = colors.textMuted;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math
            .min(constraints.maxWidth - Space.page * 2, 1160.0)
            .toDouble();
        final horizontal = (constraints.maxWidth - maxWidth) / 2;
        final cardWidth = maxWidth >= 860 ? (maxWidth - Space.l) / 2 : maxWidth;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            Space.xl,
            horizontal,
            Space.xxxl,
          ),
          child: Center(
            child: SizedBox(
              width: maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('A record of care'),
                  const SizedBox(height: Space.s),
                  Text('The collection', style: text.displayMedium),
                  const SizedBox(height: Space.s),
                  Text(
                    'A considered history for each instrument in your care.',
                    style: text.bodyLarge!.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: Space.xl),
                  AelosCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.l,
                      vertical: Space.m,
                    ),
                    child: Row(
                      children: [
                        Icon(sensorIcon, size: 20, color: sensorColor),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sensorLabel, style: text.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                activeInstrument?.instrument.name ??
                                    'Seeded history is available offline',
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (session == null && startupError == null)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: colors.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  if (awaySummary != null) ...[
                    _AwaySummaryCard(
                      summary: awaySummary!,
                      instrument: instruments
                          .where((item) => item.id == awaySummary!.instrumentId)
                          .firstOrNull,
                      onDismiss: onDismissAwaySummary,
                    ),
                    const SizedBox(height: Space.xl),
                  ],
                  Row(
                    children: [
                      const Eyebrow('Instruments'),
                      const SizedBox(width: Space.m),
                      const Expanded(child: Hairline()),
                      const SizedBox(width: Space.m),
                      Text('${instruments.length}', style: text.labelMedium),
                    ],
                  ),
                  const SizedBox(height: Space.m),
                  Wrap(
                    spacing: Space.l,
                    runSpacing: Space.l,
                    children: [
                      for (final item in instruments)
                        SizedBox(
                          width: cardWidth,
                          child: _InstrumentCard(
                            data: item,
                            live:
                                liveSession && session?.instrumentId == item.id
                                ? session?.live
                                : null,
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => InstrumentDetailScreen(
                                  instrumentId: item.id,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.l),
                  SizedBox(
                    width: double.infinity,
                    child: _AddInstrumentCard(onTap: onAddInstrument),
                  ),
                  const SizedBox(height: Space.xxl),
                  Text(
                    'Each entry is kept as a signed condition history.',
                    style: AelosText.of(context).note,
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

class _AwaySummaryCard extends StatelessWidget {
  const _AwaySummaryCard({
    required this.summary,
    required this.instrument,
    required this.onDismiss,
  });

  final AwaySummary summary;
  final InstrumentData? instrument;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final alertSummary = summary.alerts;
    final status = alertSummary?.severity ?? ConditionStatus.calm;
    final start =
        instrument?.displayTime(summary.start) ?? summary.start.toLocal();
    final end = instrument?.displayTime(summary.end) ?? summary.end.toLocal();
    final duration = end.difference(start);
    final durationText = duration.inHours > 0
        ? '${duration.inHours} h ${duration.inMinutes.remainder(60)} min'
        : '${duration.inMinutes} min';
    final humidityRange =
        summary.minTenthsHumidity == null || summary.maxTenthsHumidity == null
        ? null
        : '${(summary.minTenthsHumidity! / 10).toStringAsFixed(1)}–'
              '${(summary.maxTenthsHumidity! / 10).toStringAsFixed(1)} % RH';

    return AelosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded, color: colors.accent),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('While you were away'),
                    const SizedBox(height: Space.xs),
                    Text(
                      alertSummary?.headline ?? 'No threshold alerts',
                      style: text.titleMedium,
                    ),
                  ],
                ),
              ),
              StatusBadge(status),
              const SizedBox(width: Space.xs),
              IconButton(
                tooltip: 'Dismiss summary',
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Text(
            '${summary.recordCount} signed updates over $durationText'
            '${humidityRange == null ? '' : ' · humidity $humidityRange'}',
            style: text.bodySmall,
          ),
          if (alertSummary != null) ...[
            const SizedBox(height: Space.s),
            for (final line in alertSummary.lines.take(2))
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text(line, style: text.bodySmall),
              ),
          ],
        ],
      ),
    );
  }
}

class _InstrumentCard extends StatelessWidget {
  const _InstrumentCard({
    required this.data,
    required this.live,
    required this.onTap,
  });

  final InstrumentData data;
  final LiveReading? live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final instrument = data.instrument;
    final text = Theme.of(context).textTheme;
    final colors = AelosColors.of(context);
    final latest = data.latestReading;
    final humidity = live?.humidity ?? latest?.humidity;
    final temperature = live?.celsius ?? latest?.celsius;
    final trend = [
      for (final record in data.records.reversed)
        if (record.kind == RecordKind.reading && record.tenthsHumidity != null)
          record.tenthsHumidity! / 10,
    ].take(42).toList().reversed.toList();

    return AelosCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.9,
            child: Hero(
              tag: 'instrument-photo-${instrument.id}',
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _InstrumentPhoto(data: data),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xC9000000)],
                        stops: [0.42, 1],
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
                          '${instrument.type.label.toUpperCase()} · ${instrument.dateLabel}',
                          style: AelosText.of(context).eyebrow
                              .copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          instrument.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineMedium!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.l + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        instrument.origin ??
                            instrument.maker ??
                            'Instrument record',
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusBadge(data.status),
                  ],
                ),
                const SizedBox(height: Space.l),
                const Hairline(),
                const SizedBox(height: Space.l),
                Row(
                  children: [
                    Expanded(
                      child: _CardReading(
                        label: 'Humidity',
                        value: humidity,
                        unit: '%',
                      ),
                    ),
                    Container(width: 1, height: 42, color: colors.hairline),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: Space.l),
                        child: _CardReading(
                          label: 'Temperature',
                          value: temperature,
                          unit: '°C',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.l),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            values: trend,
                            color: colors.accent,
                            baseline: colors.hairline,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          live == null ? 'SIGNED HISTORY' : 'LIVE READING',
                          style: AelosText.of(context).eyebrow.copyWith(
                            color: live == null
                                ? colors.textFaint
                                : colors.calmInk,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          latest == null
                              ? 'NO RECORDS'
                              : 'SYNCED ${_relativeTime(data.displayTime(latest.time))}',
                          style: AelosText.of(context).eyebrow
                              .copyWith(color: colors.textFaint, fontSize: 8),
                        ),
                      ],
                    ),
                    const SizedBox(width: Space.xs),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: colors.textFaint,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentPhoto extends StatelessWidget {
  const _InstrumentPhoto({required this.data});

  final InstrumentData data;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final bytes = data.photoBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _emptyPhoto(colors),
      );
    }
    final photo = data.instrument.photo;
    if (photo == null) return _emptyPhoto(colors);
    return Image.asset(
      photo,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _emptyPhoto(colors),
    );
  }

  Widget _emptyPhoto(AelosColors colors) => ColoredBox(
    color: colors.surface,
    child: Center(
      child: FHole(height: 112, color: colors.accent.withValues(alpha: 0.5)),
    ),
  );
}

class _AddInstrumentCard extends StatelessWidget {
  const _AddInstrumentCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return AelosCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            color: colors.accent,
            size: 26,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add an instrument', style: text.titleMedium),
                const SizedBox(height: Space.xs),
                Text(
                  'Pair a sensor and begin its condition record.',
                  style: text.bodySmall!.copyWith(color: colors.textMuted),
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

class _CardReading extends StatelessWidget {
  const _CardReading({
    required this.label,
    required this.value,
    required this.unit,
  });

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
        ReadingValue(value: value!, unit: unit, size: ReadingSize.large),
    ],
  );
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.color,
    required this.baseline,
  });

  final List<double> values;
  final Color color;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = baseline
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      basePaint,
    );
    if (values.length < 2) return;

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 0.1 ? 1.0 : max - min;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * size.width / (values.length - 1);
      final y =
          size.height - 3 - ((values[i] - min) / span) * (size.height - 6);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.baseline != baseline;
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(color: AelosColors.of(context).accent),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: AelosColors.of(context).attention,
            size: 34,
          ),
          const SizedBox(height: Space.m),
          Text(
            'The collection could not be loaded',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Space.s),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

String _relativeTime(DateTime time) {
  final elapsed = DateTime.now().difference(time.toLocal());
  if (elapsed.inSeconds < 45) return 'NOW';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}M AGO';
  if (elapsed.inHours < 24) return '${elapsed.inHours}H AGO';
  return '${elapsed.inDays}D AGO';
}
