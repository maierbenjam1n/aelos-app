import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/rise_in.dart';
import '../../data/accounts.dart';
import '../../domain/models/event_report.dart';
import '../../domain/models/sensor_record.dart';
import 'fleet_instrument_screen.dart';
import 'luthier_fleet.dart';
import 'luthier_format.dart';
import 'luthier_widgets.dart';
import 'reports_tab.dart';

/// The luthier reads a renter's report (event, their words, the guided
/// photos) and moves it along: reviewed, inspection, resolved.
class ReportReviewScreen extends ConsumerWidget {
  const ReportReviewScreen({super.key, required this.reportId});

  final String reportId;

  static Future<void> open(BuildContext context, String reportId) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => ReportReviewScreen(reportId: reportId)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(fleetReportsProvider).where((r) => r.report.id == reportId).firstOrNull;
    if (report == null) {
      return Scaffold(appBar: AppBar(), body: const LuthierEmpty('This report is no longer available.'));
    }
    final r = report.report;
    final text = Theme.of(context).textTheme;
    final colors = AelosColors.of(context);
    final entry = report.entry;
    final record = _signedRecord(report);

    var i = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Event report')),
      bottomNavigationBar: _ActionBar(report: report),
      body: LuthierPage(
        bottom: Space.xl,
        children: [
          Eyebrow('Report from ${r.authorName}', color: colors.accentInk).riseIn(i++),
          const SizedBox(height: Space.s),
          Text(r.eventTitle, style: text.displaySmall).riseIn(i++),
          const SizedBox(height: Space.s),
          Text(
            'Sent ${LuthierFormat.when(report.sentTime)}',
            style: text.bodyMedium!.copyWith(color: colors.textMuted),
          ).riseIn(i++),
          const SizedBox(height: Space.xl),
          _Progress(status: r.status).riseIn(i++),
          const SizedBox(height: Space.xl),
          if (entry != null)
            AelosCard(
              onTap: () => FleetInstrumentScreen.open(context, entry.id),
              padding: const EdgeInsets.all(Space.m),
              child: Row(
                children: [
                  InstrumentThumb(data: entry.data, width: 52, height: 64),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.data.instrument.name, style: text.titleMedium),
                        Text(
                          entry.inWorkshop
                              ? 'In the workshop'
                              : 'With ${entry.rental.renterName}'
                                  '${entry.rental.since == null ? '' : ' since ${LuthierFormat.date(entry.rental.since!.toLocal())}'}',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.textFaint),
                ],
              ),
            ).riseIn(i++),
          const SizedBox(height: Space.m),
          _SignedEvent(report: report, record: record).riseIn(i++),
          const SizedBox(height: Space.xxl),
          const SectionHeader('In their words').riseIn(i++),
          _Words(report: r).riseIn(i++),
          const SizedBox(height: Space.xxl),
          SectionHeader(
            'Guided photos',
            count: r.photos.length,
          ).riseIn(i++),
          _PhotoGrid(report: report).riseIn(i++),
          if (r.luthierNote != null && r.luthierNote!.isNotEmpty) ...[
            const SizedBox(height: Space.xxl),
            const SectionHeader('Your note to the renter').riseIn(i++),
            AelosCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.edit_note_rounded, color: colors.accent),
                  const SizedBox(width: Space.m),
                  Expanded(child: Text(r.luthierNote!, style: text.bodyMedium)),
                ],
              ),
            ).riseIn(i++),
          ],
          const SizedBox(height: Space.xl),
          Text(
            'The account and photos come from the renter. The event itself is in the signed history.',
            style: AelosText.of(context).note.copyWith(fontSize: text.bodyLarge!.fontSize),
          ).riseIn(i++),
        ],
      ),
    );
  }

  /// The signed record the report refers to: by sequence number, or the
  /// impact or free fall closest to the reported time.
  static SensorRecord? _signedRecord(FleetReport report) {
    final records = report.entry?.data.records;
    if (records == null) return null;
    final seq = report.report.eventSeq;
    if (seq != null) return records.where((r) => r.seq == seq).firstOrNull;
    SensorRecord? best;
    for (final r in records) {
      if (r.kind != RecordKind.impact && r.kind != RecordKind.freeFall) continue;
      final d = r.time.difference(report.report.eventTime).abs();
      if (d > const Duration(minutes: 2)) continue;
      if (best == null || d < best.time.difference(report.report.eventTime).abs()) best = r;
    }
    return best;
  }
}

/// Sent → Reviewed → Inspection → Resolved, as lozenges on a rule.
class _Progress extends StatelessWidget {
  const _Progress({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    const steps = ['Sent', 'Reviewed', 'Inspection', 'Resolved'];
    final reached = switch (status) {
      ReportStatus.submitted => 0,
      ReportStatus.reviewed => 1,
      ReportStatus.inspectionScheduled => 2,
      ReportStatus.resolved => 3,
    };
    Widget rule(bool visible, bool done) => Expanded(
          child: AnimatedContainer(
            duration: Motion.medium,
            height: done ? 1.4 : 0.8,
            color: !visible
                ? colors.background.withValues(alpha: 0)
                : done
                    ? colors.accent
                    : colors.hairline,
          ),
        );
    // Each step is a column: the rule runs through the diamond, the label is
    // centred beneath it.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var s = 0; s < steps.length; s++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      rule(s > 0, s <= reached),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.s),
                        child: AnimatedContainer(
                          duration: Motion.medium,
                          curve: Motion.emphasis,
                          width: 10,
                          height: 10,
                          transform: Matrix4.rotationZ(0.785398), // 45°
                          transformAlignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: s <= reached ? colors.accent : colors.background,
                            border: Border.all(
                              color: s <= reached ? colors.accent : colors.textFaint,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      rule(s < steps.length - 1, s < reached),
                    ],
                  ),
                ),
                const SizedBox(height: Space.s),
                Text(
                  steps[s],
                  textAlign: TextAlign.center,
                  style: text.labelMedium!.copyWith(
                    color: s == reached ? colors.accentInk : s < reached ? colors.text : colors.textFaint,
                    fontWeight: s == reached ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SignedEvent extends StatelessWidget {
  const _SignedEvent({required this.report, required this.record});

  final FleetReport report;
  final SensorRecord? record;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final rec = record;
    final what = switch (rec?.kind) {
      RecordKind.impact => 'Impact\u00A0·\u00A0${rec!.peakG!.toStringAsFixed(1)}\u00A0g',
      RecordKind.freeFall => 'Free\u00A0fall\u00A0·\u00A0${rec!.freeFallMs}\u00A0ms',
      _ => null,
    };
    Widget row(String label, String value, {Widget? lead}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Row(
            children: [
              SizedBox(width: 100, child: Text(label, style: text.bodySmall)),
              if (lead != null) ...[lead, const SizedBox(width: Space.xs + 2)],
              Expanded(
                child: Text(
                  value,
                  style: text.bodyMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
        );
    return AelosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('The event'),
          const SizedBox(height: Space.s),
          row('Recorded', LuthierFormat.when(report.eventTime)),
          if (rec != null && what != null)
            row(
              'Signed record',
              '#${rec.seq} · $what',
              lead: Icon(Icons.verified_rounded, size: 16, color: colors.calm),
            )
          else
            row('Signed record', 'Not linked to a record'),
          if (report.report.causes.isNotEmpty) row('Cause given', report.report.causes.join(', ')),
        ],
      ),
    );
  }
}

class _Words extends StatelessWidget {
  const _Words({required this.report});

  final EventReport report;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.xs, 0, Space.xs),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.accent, width: 1.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.explanation.isEmpty ? 'No explanation given.' : '“${report.explanation}”',
            style: quoteStyle(context).copyWith(fontSize: Theme.of(context).textTheme.titleLarge!.fontSize),
          ),
          const SizedBox(height: Space.s),
          Text('— ${report.authorName}', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.report});

  final FleetReport report;

  @override
  Widget build(BuildContext context) {
    final byAngle = {for (final p in report.report.photos) p.angle: p};
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth > 560 ? 6 : 3;
        final width = (c.maxWidth - Space.m * (columns - 1)) / columns;
        return Wrap(
          spacing: Space.m,
          runSpacing: Space.l,
          children: [
            for (final angle in PhotoAngle.values)
              SizedBox(
                width: width,
                child: _PhotoTile(angle: angle, photo: byAngle[angle], report: report),
              ),
          ],
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.angle, required this.photo, required this.report});

  final PhotoAngle angle;
  final ReportPhoto? photo;
  final FleetReport report;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final p = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: p == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: const BorderRadius.all(Radii.m),
                    border: Border.all(color: colors.hairline, width: 0.8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_outlined, color: colors.textFaint, size: 20),
                        const SizedBox(height: Space.xs),
                        Text(
                          angle.optional ? 'Skipped' : 'Not taken',
                          style: text.labelMedium!.copyWith(color: colors.textFaint),
                        ),
                      ],
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => _showPhoto(context, p),
                  child: Hero(
                    tag: 'report-photo-${report.report.id}-${angle.name}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radii.m),
                      child: ReportPhotoImage(photo: p),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: Space.s),
        Text(angle.label, maxLines: 2, style: text.titleSmall),
        Text(
          p == null ? (angle.optional ? 'Optional' : '—') : LuthierFormat.clock(report.display(p.takenAt)),
          style: text.labelMedium!.copyWith(color: colors.textFaint),
        ),
      ],
    );
  }

  void _showPhoto(BuildContext context, ReportPhoto p) => Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: AelosPalette.walnutDeep.withValues(alpha: 0.95),
          transitionDuration: Motion.medium,
          reverseTransitionDuration: Motion.fast,
          pageBuilder: (context, animation, _) => FadeTransition(
            opacity: animation,
            child: _PhotoViewer(photo: p, tag: 'report-photo-${report.report.id}-${angle.name}'),
          ),
        ),
      );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo, required this.tag});

  final ReportPhoto photo;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.s, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(photo.angle.label, style: text.titleLarge!.copyWith(color: Colors.white)),
                          Text(
                            photo.angle.guidance,
                            style: text.bodySmall!.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Hero(tag: tag, child: ReportPhotoImage(photo: photo, fit: BoxFit.contain)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The next steps for the report's status, pinned to the bottom.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.report});

  final FleetReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final r = report.report;
    final notifier = ref.read(eventReportsProvider.notifier);

    void set(ReportStatus status, String message) {
      notifier.updateStatus(r.id, status);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    void reviewed() => set(ReportStatus.reviewed, 'Marked as reviewed. ${r.authorName} can see it.');
    void resolve() => set(ReportStatus.resolved, 'Report resolved.');
    void inspect() => _showInspectionSheet(context, report);

    final (primary, secondary, tertiary) = switch (r.status) {
      ReportStatus.submitted => (
          ('Mark reviewed', Icons.visibility_outlined, reviewed),
          ('Schedule inspection', inspect),
          ('Resolve', resolve),
        ),
      ReportStatus.reviewed => (
          ('Schedule inspection', Icons.event_available_outlined, inspect),
          ('Resolve', resolve),
          null,
        ),
      ReportStatus.inspectionScheduled => (
          ('Resolve', Icons.task_alt_rounded, resolve),
          ('Change inspection', inspect),
          null,
        ),
      ReportStatus.resolved => (null, null, null),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.hairline, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, Space.s),
          child: AnimatedSize(
            duration: Motion.medium,
            curve: Motion.emphasis,
            child: primary == null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: Space.s),
                    child: Row(
                      children: [
                        Icon(ReportStatus.resolved.icon, color: colors.calm, size: 20),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: Text(
                            'Resolved. The report stays with the instrument’s record.',
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: primary.$3,
                        icon: Icon(primary.$2, size: 20),
                        label: Text(primary.$1),
                      ),
                      const SizedBox(height: Space.xs),
                      Row(
                        children: [
                          if (secondary != null)
                            Expanded(child: _Quiet(label: secondary.$1, onPressed: secondary.$2)),
                          if (tertiary != null) ...[
                            Container(width: 0.8, height: 20, color: colors.hairline),
                            Expanded(child: _Quiet(label: tertiary.$1, onPressed: tertiary.$2)),
                          ],
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A secondary text action that shrinks rather than wraps on narrow phones.
class _Quiet extends StatelessWidget {
  const _Quiet({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
      );
}

Future<void> _showInspectionSheet(BuildContext context, FleetReport report) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AelosColors.of(context).surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radii.l)),
      builder: (_) => InspectionSheet(report: report),
    );

/// When the renter should bring the instrument in, and an optional note.
class InspectionSheet extends ConsumerStatefulWidget {
  const InspectionSheet({super.key, required this.report});

  final FleetReport report;

  @override
  ConsumerState<InspectionSheet> createState() => _InspectionSheetState();
}

class _InspectionSheetState extends ConsumerState<InspectionSheet> {
  static const _whens = ['Tomorrow', 'This week', 'Next week'];
  String _when = _whens.first;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _confirm() {
    final r = widget.report.report;
    final note = _note.text.trim();
    ref.read(eventReportsProvider.notifier).updateStatus(
          r.id,
          ReportStatus.inspectionScheduled,
          note: note.isEmpty ? 'Inspection: $_when.' : 'Inspection: $_when. $note',
        );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Inspection scheduled. ${r.authorName} will see your note.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final name = widget.report.entry?.data.instrument.name ?? 'the instrument';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Eyebrow('Schedule inspection', color: colors.accentInk),
              const SizedBox(height: Space.s),
              Text('Bring it to the bench', style: text.headlineMedium),
              const SizedBox(height: Space.xs),
              Text(
                'Ask ${widget.report.report.authorName} to bring the $name to the workshop.',
                style: text.bodySmall,
              ),
              const SizedBox(height: Space.l),
              const Eyebrow('When'),
              const SizedBox(height: Space.s),
              LuthierSegmented<String>(
                segments: [for (final w in _whens) (w, w)],
                selected: _when,
                onChanged: (w) => setState(() => _when = w),
              ),
              const SizedBox(height: Space.l),
              const Eyebrow('Note to the renter · optional'),
              const SizedBox(height: Space.s),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: text.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'E.g. Keep it in the case until then; I will check the seams and the soundpost.',
                  hintStyle: text.bodyMedium!.copyWith(color: colors.textFaint),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.all(Space.m),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radii.m),
                    borderSide: BorderSide(color: colors.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radii.m),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              FilledButton(onPressed: _confirm, child: const Text('Schedule inspection')),
            ],
          ),
        ),
      ),
    );
  }
}
