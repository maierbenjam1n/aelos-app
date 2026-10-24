import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/hairline.dart';
import '../../domain/passport/passport_bundle.dart';
import '../../domain/verification/chain_verifier.dart';

/// Imports a `.aelos` bundle and reports its signed-record verification result.
class PassportVerifyScreen extends StatefulWidget {
  const PassportVerifyScreen({super.key});

  @override
  State<PassportVerifyScreen> createState() => _PassportVerifyScreenState();
}

class _PassportVerifyScreenState extends State<PassportVerifyScreen> {
  PassportVerification? _result;
  String? _fileName;
  String? _error;
  bool _loading = false;

  Future<void> _chooseBundle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['aelos'],
      );
      if (!mounted || file == null) return;
      final size = await file.length();
      if (size != null && size > 50 * 1024 * 1024) {
        setState(() => _error = 'Choose an Aelos bundle smaller than 50 MB.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final result = await verifyPassportBundle(bytes, isolates: 4);
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _result = result;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _fileName = null;
          _result = null;
          _error = _cleanError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanError(Object error) {
    final message = error.toString().replaceFirst('FormatException: ', '');
    if (message.startsWith('Bad state: ')) return message.substring(11);
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify a passport')),
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
                  const Eyebrow('Signed provenance'),
                  const SizedBox(height: Space.s),
                  Text('Verify a history.', style: text.displayMedium),
                  const SizedBox(height: Space.s),
                  Text(
                    'Choose an .aelos bundle to check its record sequence, signatures and hash chain.',
                    style: text.bodyLarge!.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: Space.xl),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _chooseBundle,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 1.8),
                          )
                        : const Icon(Icons.folder_open_outlined),
                    label: Text(
                      _loading ? 'Checking records…' : 'Choose .aelos bundle',
                    ),
                  ),
                  if (_fileName != null) ...[
                    const SizedBox(height: Space.s),
                    Text(
                      _fileName!,
                      textAlign: TextAlign.center,
                      style: text.bodySmall!.copyWith(color: colors.textMuted),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: Space.xl),
                    _FailureCard(message: _error!),
                  ],
                  if (_result case final result?) ...[
                    const SizedBox(height: Space.xl),
                    _ResultCard(result: result),
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final PassportVerification result;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    if (!result.isValid) {
      final index = result.chain.failedAtIndex;
      final record = index == null || index >= result.records.length
          ? null
          : result.records[index];
      final reason = switch (result.chain.reason) {
        ChainFailure.malformed => 'Record is malformed',
        ChainFailure.sequence => 'Sequence is missing or out of order',
        ChainFailure.signature => 'Signature does not match the sensor key',
        null => 'The record chain could not be verified',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AelosCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gpp_bad_outlined, color: colors.actNow, size: 26),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('Seal not valid', color: colors.actNowInk),
                      const SizedBox(height: Space.s),
                      Text(
                        'History verification failed',
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: Space.s),
                      Text(
                        record == null
                            ? reason
                            : '$reason at record ${record.seq}.',
                        style: text.bodyMedium!.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (record != null) ...[
            const SizedBox(height: Space.m),
            AelosCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('First failing record', color: colors.actNowInk),
                  const SizedBox(height: Space.s),
                  Text('Sequence ${record.seq}', style: text.titleMedium),
                  const SizedBox(height: Space.xs),
                  Text(
                    '${record.kind.name} · ${record.time.toLocal()}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.s),
          Text(
            'Do not rely on this bundle as an unaltered sensor history.',
            style: text.bodySmall!.copyWith(color: colors.actNowInk),
          ),
        ],
      );
    }

    final withGaps = result.hasGaps;
    final markColor = withGaps ? colors.attentionInk : colors.calmInk;
    final icon = withGaps ? Icons.verified_outlined : Icons.verified_rounded;
    return AelosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: markColor, size: 28),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(
                      withGaps ? 'Verified with gaps' : 'Verified',
                      color: markColor,
                    ),
                    const SizedBox(height: Space.s),
                    Text(
                      result.manifest.instrument.name,
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'All ${result.records.length} sensor records passed sequence, signature and hash-chain checks.',
                      style: text.bodySmall!.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          const Hairline(),
          const SizedBox(height: Space.l),
          Text(
            'Aelos-${result.manifest.deviceId} · ${result.manifest.instrument.type.label} · ${result.manifest.instrument.dateLabel}',
            style: text.bodyMedium,
          ),
          const SizedBox(height: Space.xs),
          Text(
            '${result.records.first.seq}–${result.records.last.seq} · ${result.records.length} records',
            style: text.bodySmall!.copyWith(color: colors.textMuted),
          ),
          if (withGaps) ...[
            const SizedBox(height: Space.l),
            Eyebrow('Reading gaps · ${result.gaps.length}'),
            const SizedBox(height: Space.s),
            for (final gap in result.gaps.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Text(
                  '${gap.start.toLocal()} to ${gap.end.toLocal()} · ${_duration(gap.duration)}',
                  style: text.bodySmall,
                ),
              ),
            if (result.gaps.length > 3)
              Text('And ${result.gaps.length - 3} more', style: text.bodySmall),
          ],
          const SizedBox(height: Space.l),
          Text(
            'The signatures authenticate sensor records. Instrument profile details and the date range are owner-supplied metadata.',
            style: text.bodySmall!.copyWith(color: colors.textMuted),
          ),
          if (result.photoBytes != null) ...[
            const SizedBox(height: Space.l),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radii.s),
              child: Image.memory(
                result.photoBytes!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _duration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays} days';
    if (duration.inHours > 0) return '${duration.inHours} h';
    return '${duration.inMinutes} min';
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return AelosCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_bad_outlined, color: colors.actNow, size: 26),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('Could not verify', color: colors.actNowInk),
                const SizedBox(height: Space.s),
                Text(message, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
