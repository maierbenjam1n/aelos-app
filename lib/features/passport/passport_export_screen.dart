import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/hairline.dart';
import '../../data/instrument_data.dart';
import '../../data/instruments_notifier.dart';
import '../../domain/passport/passport_bundle.dart';
import 'passport_pdf.dart';

enum _PassportRange {
  week('7 days', Duration(days: 7)),
  month('30 days', Duration(days: 30)),
  all('All history', null);

  const _PassportRange(this.label, this.duration);

  final String label;
  final Duration? duration;
}

/// Creates and shares the printable passport and signed `.aelos` bundle.
class PassportExportScreen extends ConsumerStatefulWidget {
  const PassportExportScreen({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  ConsumerState<PassportExportScreen> createState() =>
      _PassportExportScreenState();
}

class _PassportExportScreenState extends ConsumerState<PassportExportScreen> {
  _PassportRange _range = _PassportRange.week;
  bool _sharing = false;

  Future<void> _share(InstrumentData data) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final to = data.sensorNow;
      final from = _range.duration == null
          ? data.records.first.time
          : to.subtract(_range.duration!);
      final photoBytes = await _photoBytes(data);
      final passport = createPassportExport(
        instrument: data.instrument,
        history: data.records,
        from: from,
        to: to,
        photoBytes: photoBytes,
      );
      final pdf = await createPassportPdf(passport);
      if (!mounted) return;
      final filename = _fileSlug(data.instrument.name);
      final box = context.findRenderObject() as RenderBox?;
      final shareResult = await SharePlus.instance.share(
        ShareParams(
          title: 'Condition passport · ${data.instrument.name}',
          subject: 'Aelos condition passport for ${data.instrument.name}',
          text: 'The PDF summary and signed sensor history are attached.',
          files: [
            XFile.fromData(
              pdf,
              name: '$filename-passport.pdf',
              mimeType: 'application/pdf',
            ),
            XFile.fromData(
              passport.bytes,
              name: '$filename.aelos',
              mimeType: 'application/zip',
            ),
          ],
          fileNameOverrides: ['$filename-passport.pdf', '$filename.aelos'],
          downloadFallbackEnabled: true,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (mounted && shareResult.status == ShareResultStatus.unavailable) {
        _message('Sharing is not available on this device.');
      }
    } on Object catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<Uint8List?> _photoBytes(InstrumentData data) async {
    if (data.photoBytes != null) return data.photoBytes;
    final asset = data.instrument.photo;
    if (asset == null) return null;
    try {
      final photo = await rootBundle.load(asset);
      return photo.buffer.asUint8List(photo.offsetInBytes, photo.lengthInBytes);
    } on Object {
      return null;
    }
  }

  String _fileSlug(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-|-$)'), '');
    return slug.isEmpty ? 'aelos-instrument' : slug;
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(instrumentProvider(widget.instrumentId));
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Condition passport')),
        body: Center(child: CircularProgressIndicator(color: colors.accent)),
      );
    }
    final canExport = data.records.isNotEmpty;
    final rangeText = _range.duration == null
        ? 'The complete signed history'
        : 'Records from the last ${_range.label.toLowerCase()}';

    return Scaffold(
      appBar: AppBar(title: const Text('Condition passport')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.page,
            Space.m,
            Space.page,
            Space.xxxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Eyebrow('A record you can share'),
                  const SizedBox(height: Space.s),
                  Text('Condition passport', style: text.displayMedium),
                  const SizedBox(height: Space.s),
                  Text(
                    'A designed certificate and the signed records behind it.',
                    style: text.bodyLarge!.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: Space.xl),
                  AelosCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.instrument.name, style: text.titleLarge),
                        const SizedBox(height: Space.xs),
                        Text(
                          '${data.instrument.type.label} · ${data.instrument.dateLabel}',
                          style: text.bodyMedium!.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: Space.l),
                        const Hairline(),
                        const SizedBox(height: Space.l),
                        Row(
                          children: [
                            Expanded(
                              child: _Summary(
                                label: 'Signed records',
                                value: '${data.records.length}',
                              ),
                            ),
                            Expanded(
                              child: _Summary(
                                label: 'Sensor',
                                value: 'Aelos-${data.instrument.sensorId}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  const Eyebrow('Date range'),
                  const SizedBox(height: Space.m),
                  SegmentedButton<_PassportRange>(
                    segments: [
                      for (final range in _PassportRange.values)
                        ButtonSegment(value: range, label: Text(range.label)),
                    ],
                    selected: {_range},
                    showSelectedIcon: false,
                    onSelectionChanged: (selected) =>
                        setState(() => _range = selected.single),
                  ),
                  const SizedBox(height: Space.s),
                  Text(rangeText, style: text.bodySmall),
                  const SizedBox(height: Space.xl),
                  AelosCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: colors.accent),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Text(
                            'The sensor signs each history record. Instrument details and the selected date range are supplied by the owner and are not sensor-signed.',
                            style: text.bodySmall!.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  FilledButton.icon(
                    onPressed: canExport && !_sharing
                        ? () => _share(data)
                        : null,
                    icon: _sharing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(
                      _sharing
                          ? 'Preparing passport…'
                          : 'Share PDF and .aelos bundle',
                    ),
                  ),
                  if (!canExport) ...[
                    const SizedBox(height: Space.s),
                    Text(
                      'There are no signed records to export yet.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall!.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall!.copyWith(color: colors.textMuted)),
        const SizedBox(height: Space.xs),
        Text(value, style: text.titleSmall),
      ],
    );
  }
}
