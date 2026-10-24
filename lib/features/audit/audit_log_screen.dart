import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/hairline.dart';
import '../../data/instrument_data.dart';
import '../../data/instruments_notifier.dart';
import '../../domain/models/audit_incident.dart';
import '../../domain/models/sensor_record.dart';
import '../../domain/thresholds/alert.dart';
import '../../domain/verification/chain_verifier.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  _AuditFilter _filter = _AuditFilter.all;
  String _query = '';
  ChainResult? _chainResult;
  int? _checkedRecordCount;
  bool _checking = false;
  String? _checkError;

  Future<void> _checkChain(InstrumentData data) async {
    if (_checking || data.records.isEmpty) return;
    setState(() {
      _checking = true;
      _checkError = null;
      _chainResult = null;
      _checkedRecordCount = null;
    });
    try {
      final result = await verifyChain(
        [for (final record in data.records) record.json],
        publicKey: base64Decode(data.instrument.sensorPublicKey),
        isolates: 4,
      );
      if (!mounted) return;
      if (ref.read(instrumentProvider(widget.instrumentId))?.records.length !=
          data.records.length) {
        return;
      }
      setState(() {
        _chainResult = result;
        _checkedRecordCount = data.records.length;
      });
    } on Object catch (error) {
      if (!mounted) return;
      if (ref.read(instrumentProvider(widget.instrumentId))?.records.length !=
          data.records.length) {
        return;
      }
      setState(() => _checkError = error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(instrumentProvider(widget.instrumentId), (previous, next) {
      if (previous?.records.length != next?.records.length) {
        setState(() {
          _chainResult = null;
          _checkedRecordCount = null;
          _checkError = null;
        });
      }
    });
    final data = ref.watch(instrumentProvider(widget.instrumentId));
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit log')),
        body: Center(
          child: CircularProgressIndicator(
            color: AelosColors.of(context).accent,
          ),
        ),
      );
    }

    final entries = _entries(data);
    final visibleEntries = entries.where(_matches).toList();
    final counts = _filterCounts(entries);
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - Space.page * 2)
              .clamp(0.0, 880.0)
              .toDouble();
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, Space.m, 0, Space.m),
                    sliver: SliverToBoxAdapter(
                      child: _AuditOverview(
                        data: data,
                        checking: _checking,
                        result: _chainResult,
                        checkError: _checkError,
                        onCheck: () => _checkChain(data),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search records, alerts or sequence',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () => setState(() => _query = ''),
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.m),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final filter in _AuditFilter.values) ...[
                              if (filter != _AuditFilter.values.first)
                                const SizedBox(width: Space.s),
                              ChoiceChip(
                                label: Text(
                                  '${filter.label} · ${counts[filter] ?? 0}',
                                ),
                                selected: _filter == filter,
                                onSelected: (_) =>
                                    setState(() => _filter = filter),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (visibleEntries.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyAudit(filter: _filter, query: _query),
                    )
                  else
                    SliverList.builder(
                      itemCount: visibleEntries.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: Space.s),
                        child: _AuditEntryCard(
                          entry: visibleEntries[index],
                          data: data,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<_AuditFilter, int> _filterCounts(List<_AuditEntry> entries) {
    return {
      for (final filter in _AuditFilter.values)
        filter: entries.where((entry) => _inFilter(entry, filter)).length,
    };
  }

  List<_AuditEntry> _entries(InstrumentData data) {
    final alertsBySequence = <int, List<Alert>>{};
    for (final alert in data.alerts) {
      for (final sequence in alert.seqs) {
        alertsBySequence.putIfAbsent(sequence, () => []).add(alert);
      }
    }
    final failedIndex = _checkedRecordCount == data.records.length
        ? _chainResult?.failedAtIndex
        : null;
    final entries = <_AuditEntry>[
      for (final (index, record) in data.records.indexed)
        _AuditEntry.record(
          record: record,
          index: index,
          alerts: alertsBySequence[record.seq] ?? const [],
          chainFailure: failedIndex == index ? _chainResult?.reason : null,
        ),
      for (final incident in data.integrityIncidents)
        _AuditEntry.incident(incident: incident),
    ];
    entries.sort((a, b) {
      final timeOrder = b.time.compareTo(a.time);
      if (timeOrder != 0) return timeOrder;
      return (b.sequence ?? 0).compareTo(a.sequence ?? 0);
    });
    return entries;
  }

  bool _matches(_AuditEntry entry) {
    if (!_inFilter(entry, _filter)) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return entry.searchText.toLowerCase().contains(query);
  }

  bool _inFilter(_AuditEntry entry, _AuditFilter filter) => switch (filter) {
    _AuditFilter.all => true,
    _AuditFilter.climate => entry.record?.kind == RecordKind.reading,
    _AuditFilter.events =>
      entry.incident == null &&
          (entry.record?.kind != RecordKind.reading || entry.alerts.isNotEmpty),
    _AuditFilter.integrity =>
      entry.incident != null || entry.chainFailure != null,
  };
}

enum _AuditFilter { all, climate, events, integrity }

extension on _AuditFilter {
  String get label => switch (this) {
    _AuditFilter.all => 'All',
    _AuditFilter.climate => 'Climate',
    _AuditFilter.events => 'Events',
    _AuditFilter.integrity => 'Integrity',
  };
}

final class _AuditEntry {
  const _AuditEntry.record({
    required this.record,
    required this.index,
    required this.alerts,
    this.chainFailure,
  }) : incident = null;

  const _AuditEntry.incident({required this.incident})
    : record = null,
      index = null,
      alerts = const [],
      chainFailure = null;

  final SensorRecord? record;
  final AuditIncident? incident;
  final int? index;
  final List<Alert> alerts;
  final ChainFailure? chainFailure;

  int? get sequence => record?.seq ?? incident?.sequence;
  DateTime get time => record == null ? incident!.observedAt : record!.time;

  String get searchText => [
    sequence,
    record?.kind.name,
    record?.raw,
    incident?.rawRecord,
    incident?.failure.name,
    chainFailure?.name,
    for (final alert in alerts) ...[alert.title, alert.why, alert.whatToDo],
  ].join(' ');
}

class _AuditOverview extends StatelessWidget {
  const _AuditOverview({
    required this.data,
    required this.checking,
    required this.result,
    required this.checkError,
    required this.onCheck,
  });

  final InstrumentData data;
  final bool checking;
  final ChainResult? result;
  final String? checkError;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AelosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(data.instrument.name.toUpperCase()),
              const SizedBox(height: Space.s),
              Text(
                'A complete record of the sensor’s history',
                style: text.headlineSmall,
              ),
              const SizedBox(height: Space.m),
              Wrap(
                spacing: Space.l,
                runSpacing: Space.s,
                children: [
                  _CountLabel(
                    value: '${data.records.length}',
                    label: 'signed records',
                  ),
                  _CountLabel(value: '${data.alerts.length}', label: 'alerts'),
                  _CountLabel(
                    value: '${data.integrityIncidents.length}',
                    label: 'rejected records',
                    color: data.integrityIncidents.isEmpty
                        ? null
                        : colors.attention,
                  ),
                ],
              ),
              const SizedBox(height: Space.m),
              const Hairline(),
              const SizedBox(height: Space.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Run a full signature and sequence check across every stored record.',
                      style: text.bodySmall,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  FilledButton.tonalIcon(
                    onPressed: checking || data.records.isEmpty
                        ? null
                        : onCheck,
                    icon: checking
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user_outlined, size: 18),
                    label: Text(checking ? 'Checking' : 'Check chain'),
                  ),
                ],
              ),
              if (data.records.isEmpty) ...[
                const SizedBox(height: Space.s),
                Text(
                  'The sensor has not added any signed records yet.',
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (result != null || checkError != null) ...[
          const SizedBox(height: Space.s),
          _VerificationResult(result: result, error: checkError),
        ],
      ],
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return RichText(
      text: TextSpan(
        style: text.bodySmall,
        children: [
          TextSpan(
            text: '$value ',
            style: text.labelLarge?.copyWith(color: color),
          ),
          TextSpan(text: label),
        ],
      ),
    );
  }
}

class _VerificationResult extends StatelessWidget {
  const _VerificationResult({this.result, this.error});

  final ChainResult? result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final valid = result?.isValid ?? false;
    final color = error != null
        ? colors.attention
        : valid
        ? colors.calm
        : colors.actNow;
    final title = error != null
        ? 'Could not complete the check'
        : valid
        ? 'Chain verified'
        : 'Chain check failed';
    final detail =
        error ??
        (valid
            ? 'All ${result!.count} records passed the sequence, hash and signature checks.'
            : 'First failure at sequence ${result!.failedAtSeq ?? 'unknown'} · ${result!.reason!.label}.');
    return AelosCard(
      padding: const EdgeInsets.all(Space.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error != null
                ? Icons.warning_amber_rounded
                : valid
                ? Icons.verified_rounded
                : Icons.gpp_bad_outlined,
            color: color,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(color: color)),
                const SizedBox(height: Space.xs),
                Text(detail, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  const _AuditEntryCard({required this.entry, required this.data});

  final _AuditEntry entry;
  final InstrumentData data;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final record = entry.record;
    final incident = entry.incident;
    final time = record == null
        ? incident!.observedAt.toLocal()
        : data.displayTime(record.time);
    final headline = incident != null
        ? 'Rejected record · ${incident.failure.label}'
        : entry.chainFailure != null
        ? 'Chain check failed · ${entry.chainFailure!.label}'
        : _recordHeadline(record!);
    final summary = incident != null
        ? 'Sequence ${incident.sequence}'
        : _recordSummary(record!);
    final statusColor = incident != null || entry.chainFailure != null
        ? colors.actNow
        : entry.alerts.isNotEmpty
        ? colors.attention
        : colors.accent;
    final icon = incident != null
        ? Icons.gpp_bad_outlined
        : entry.chainFailure != null
        ? Icons.warning_amber_rounded
        : _recordIcon(record!.kind);

    return AelosCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: Space.l,
          vertical: Space.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          Space.l,
          0,
          Space.l,
          Space.l,
        ),
        leading: Icon(icon, color: statusColor),
        title: Text(headline, style: text.titleSmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Text(
            'SEQ ${entry.sequence ?? '—'}  ·  ${_formatTime(time)}\n$summary',
            style: text.bodySmall,
          ),
        ),
        children: [
          if (incident != null)
            _IncidentDetails(incident: incident)
          else
            _RecordDetails(entry: entry, data: data),
        ],
      ),
    );
  }
}

extension on ChainFailure {
  String get label => switch (this) {
    ChainFailure.malformed => 'malformed record',
    ChainFailure.sequence => 'sequence gap or reorder',
    ChainFailure.signature => 'signature or chain mismatch',
  };
}

String _recordHeadline(SensorRecord record) => switch (record.kind) {
  RecordKind.reading => 'Climate reading',
  RecordKind.impact => 'Impact detected',
  RecordKind.freeFall => 'Free fall detected',
  RecordKind.boot => 'Sensor started',
};

String _recordSummary(SensorRecord record) => switch (record.kind) {
  RecordKind.reading =>
    '${record.humidity?.toStringAsFixed(1) ?? '—'} % RH  ·  ${record.celsius?.toStringAsFixed(1) ?? '—'} °C',
  RecordKind.impact => 'Peak ${record.peakG?.toStringAsFixed(1) ?? '—'} g',
  RecordKind.freeFall => '${record.freeFallMs ?? '—'} ms free fall',
  RecordKind.boot => 'Signed sensor event',
};

IconData _recordIcon(RecordKind kind) => switch (kind) {
  RecordKind.reading => Icons.thermostat_rounded,
  RecordKind.impact => Icons.vibration_rounded,
  RecordKind.freeFall => Icons.south_rounded,
  RecordKind.boot => Icons.power_settings_new_rounded,
};

String _formatTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)}  ${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

class _RecordDetails extends StatelessWidget {
  const _RecordDetails({required this.entry, required this.data});

  final _AuditEntry entry;
  final InstrumentData data;

  @override
  Widget build(BuildContext context) {
    final record = entry.record!;
    final index = entry.index!;
    final previousHash = index == 0
        ? zeroPrev
        : recordHash(data.records[index - 1].json);
    final currentHash = recordHash(record.json);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final alert in entry.alerts) ...[
          _AlertRationale(alert: alert),
          const SizedBox(height: Space.m),
        ],
        if (entry.chainFailure != null) ...[
          const _InlineNotice(
            icon: Icons.warning_amber_rounded,
            text: 'This record is where the full-history check first failed.',
          ),
          const SizedBox(height: Space.m),
        ],
        const Eyebrow('CHAIN DETAILS'),
        const SizedBox(height: Space.s),
        _HashLine(label: 'Previous hash', value: _hex(previousHash)),
        const SizedBox(height: Space.xs),
        _HashLine(label: 'Record hash', value: _hex(currentHash)),
        const SizedBox(height: Space.xs),
        _HashLine(label: 'Ed25519 signature', value: record.signature),
        const SizedBox(height: Space.m),
        const Eyebrow('SIGNED RECORD JSON'),
        const SizedBox(height: Space.xs),
        _RawJson(raw: record.raw),
      ],
    );
  }
}

class _IncidentDetails extends StatelessWidget {
  const _IncidentDetails({required this.incident});

  final AuditIncident incident;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InlineNotice(
        icon: Icons.gpp_bad_outlined,
        text:
            'Rejected at ${_formatTime(incident.observedAt.toLocal())}. This record was not added to the signed history.',
      ),
      const SizedBox(height: Space.m),
      const Eyebrow('RECEIVED RECORD JSON'),
      const SizedBox(height: Space.xs),
      _RawJson(raw: incident.rawRecord),
    ],
  );
}

class _AlertRationale extends StatelessWidget {
  const _AlertRationale({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: colors.statusTint(alert.severity),
        borderRadius: const BorderRadius.all(Radii.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert.title,
            style: text.titleSmall?.copyWith(
              color: colors.statusInk(alert.severity),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(alert.why, style: text.bodySmall),
          const SizedBox(height: Space.xs),
          Text(alert.whatToDo, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _HashLine extends StatelessWidget {
  const _HashLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall),
        SelectableText(
          value,
          style: text.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _RawJson extends StatelessWidget {
  const _RawJson({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.all(Radii.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Copy JSON',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: raw));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Record JSON copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              raw,
              style: text.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.attention),
        const SizedBox(width: Space.s),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _EmptyAudit extends StatelessWidget {
  const _EmptyAudit({required this.filter, required this.query});

  final _AuditFilter filter;
  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            query.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.receipt_long_rounded,
            size: 30,
            color: AelosColors.of(context).textFaint,
          ),
          const SizedBox(height: Space.m),
          Text(
            query.isNotEmpty
                ? 'No records match “$query”.'
                : switch (filter) {
                    _AuditFilter.integrity =>
                      'No integrity incidents recorded.',
                    _AuditFilter.events =>
                      'No sensor events or alerts recorded.',
                    _ => 'No records in this section yet.',
                  },
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
