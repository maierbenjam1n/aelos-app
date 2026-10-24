import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/eyebrow.dart';
import '../../data/accounts.dart';
import '../../data/instruments_notifier.dart';
import '../../domain/models/account.dart';
import '../../domain/models/event_report.dart';
import '../../domain/models/instrument.dart';
import 'explanation_step.dart';
import 'photo_source.dart';
import 'photo_step.dart';
import 'report_copy.dart';
import 'report_sent.dart';
import 'review_step.dart';

/// Guided documentation of one signed event: what happened, then one photo
/// per [PhotoAngle], then review and submit to `eventReportsProvider`.
/// Renters send it to their luthier; owners add it to their own history.
class EventReportFlow extends ConsumerStatefulWidget {
  const EventReportFlow({
    super.key,
    required this.instrumentId,
    required this.eventTitle,
    required this.eventTime,
    this.eventSeq,
    @visibleForTesting this.initialStep = 0,
    @visibleForTesting this.initialPhotos = const {},
    @visibleForTesting this.initialCauses = const {},
    @visibleForTesting this.initialExplanation = '',
  });

  final String instrumentId;

  /// E.g. "Strong impact recorded · 7.2 g".
  final String eventTitle;

  /// Signed time of the event; shown through the instrument's displayTime.
  final DateTime eventTime;

  /// Sequence number of the signed record, if known.
  final int? eventSeq;

  final int initialStep;
  final Map<PhotoAngle, ReportPhoto> initialPhotos;
  final Set<String> initialCauses;
  final String initialExplanation;

  /// Full-screen route that rises from the bottom, as a task should.
  static Route<void> route({
    required String instrumentId,
    required String eventTitle,
    required DateTime eventTime,
    int? eventSeq,
  }) =>
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EventReportFlow(
          instrumentId: instrumentId,
          eventTitle: eventTitle,
          eventTime: eventTime,
          eventSeq: eventSeq,
        ),
      );

  @override
  ConsumerState<EventReportFlow> createState() => _EventReportFlowState();
}

/// Explanation, one step per angle, review.
final _stepCount = PhotoAngle.values.length + 2;

class _EventReportFlowState extends ConsumerState<EventReportFlow> {
  late int _step = widget.initialStep;
  int _direction = 1;
  late final _photos = Map<PhotoAngle, ReportPhoto>.of(widget.initialPhotos);
  late final _causes = Set<String>.of(widget.initialCauses);
  late final _explanation = TextEditingController(text: widget.initialExplanation);
  final _lastOrigin = <PhotoAngle, PhotoOrigin>{};
  bool _busy = false;
  String? _message;
  bool _sent = false;
  Timer? _closeTimer;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _explanation.dispose();
    super.dispose();
  }

  bool get _hasDraft => _photos.isNotEmpty || _causes.isNotEmpty || _explanation.text.trim().isNotEmpty;

  PhotoAngle? get _angle {
    final i = _step - 1;
    return i >= 0 && i < PhotoAngle.values.length ? PhotoAngle.values[i] : null;
  }

  void _go(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _direction = step >= _step ? 1 : -1;
      _step = step.clamp(0, _stepCount - 1);
      _message = null;
    });
  }

  void _next() => _go(_step + 1);

  Future<void> _back() async {
    if (_step > 0) return _go(_step - 1);
    await _close();
  }

  Future<void> _close() async {
    final navigator = Navigator.of(context);
    if (!_hasDraft || _sent) {
      navigator.pop();
      return;
    }
    final discard = await _ask(
      title: 'Leave without saving?',
      body: 'Your notes and photos for this event will be discarded.',
      confirm: 'Keep documenting',
      alternative: 'Discard',
    );
    if (discard == false && mounted) navigator.pop();
  }

  Future<void> _pick(PhotoAngle angle, PhotoOrigin origin) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await ref.read(photoSourceProvider).pick(origin);
    if (!mounted) return;
    final now = ref.read(instrumentProvider(widget.instrumentId))?.sensorNow ?? DateTime.now().toUtc();
    setState(() {
      _busy = false;
      switch (result) {
        case PhotoPicked(:final bytes):
          _lastOrigin[angle] = origin;
          _photos[angle] = ReportPhoto(angle: angle, takenAt: now, bytes: bytes);
          HapticFeedback.lightImpact();
        case PhotoCancelled():
          break;
        case PhotoUnavailable(:final message):
          _message = message;
      }
    });
  }

  Future<void> _skip(PhotoAngle angle) async {
    if (angle.optional) return _next();
    final takePhoto = await _ask(
      title: 'Skip ${angle.title.toLowerCase()}?',
      body: 'A luthier reads damage best from every side. You can still add it from the review.',
      confirm: 'Take the photo',
      alternative: 'Skip for now',
    );
    if (takePhoto == false) _next();
  }

  /// A calm two-choice sheet. True for [confirm], false for [alternative],
  /// null if dismissed.
  Future<bool?> _ask({
    required String title,
    required String body,
    required String confirm,
    required String alternative,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        backgroundColor: AelosColors.of(context).surface,
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: text.headlineSmall),
                  const SizedBox(height: Space.s),
                  Text(body, style: text.bodyMedium!.copyWith(color: AelosColors.of(context).textMuted)),
                  const SizedBox(height: Space.xl),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirm)),
                  const SizedBox(height: Space.xs),
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(alternative)),
                ],
              ),
            ),
          );
        },
      );

  Luthier? _luthier() {
    final account = ref.read(accountProvider);
    if (account?.role != AccountRole.renter) return null;
    final rental = ref.read(rentalsProvider.notifier).forInstrument(widget.instrumentId);
    return DemoDirectory.luthierById(rental?.luthierId ?? account?.luthierId);
  }

  void _submit() {
    final data = ref.read(instrumentProvider(widget.instrumentId));
    final account = ref.read(accountProvider);
    final luthier = _luthier();
    final now = data?.sensorNow ?? DateTime.now().toUtc();
    ref.read(eventReportsProvider.notifier).submit(
          EventReport(
            id: 'report-${widget.instrumentId}-${DateTime.now().microsecondsSinceEpoch}',
            instrumentId: widget.instrumentId,
            eventSeq: widget.eventSeq,
            eventTitle: widget.eventTitle,
            eventTime: widget.eventTime,
            explanation: _explanation.text.trim(),
            causes: [for (final c in reportCauses) if (_causes.contains(c)) c],
            photos: [for (final a in PhotoAngle.values) ?_photos[a]],
            authorId: account?.id ?? 'owner',
            authorName: account?.name ?? 'Owner',
            createdAt: now,
            luthierId: luthier?.id,
          ),
        );
    HapticFeedback.mediumImpact();
    setState(() => _sent = true);
    _closeTimer = Timer(Motion.chartDraw * 3, _finish);
  }

  void _finish() {
    _closeTimer?.cancel();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(instrumentProvider(widget.instrumentId));
    final type = data?.instrument.type ?? InstrumentType.violin;
    final event = EventSummary(
      title: widget.eventTitle,
      when: formatWhen(data?.displayTime(widget.eventTime) ?? widget.eventTime.toLocal()),
      instrumentName: data?.instrument.name ?? 'Instrument',
      seq: widget.eventSeq,
    );
    final luthier = _luthier();

    final Widget body;
    if (_sent) {
      body = ReportSent(
        key: const ValueKey('sent'),
        title: luthier == null ? 'Added to the condition history' : 'Sent to ${luthier.workshop}',
        detail: luthier == null
            ? 'It sits beside the signed record of the event, with your photos.'
            : '${luthier.master} will look at the photos and get back to you.',
        onDone: _finish,
      );
    } else if (_step == 0) {
      body = ExplanationStep(
        key: const ValueKey(0),
        event: event,
        causes: _causes,
        onToggleCause: (c) => setState(() => _causes.contains(c) ? _causes.remove(c) : _causes.add(c)),
        controller: _explanation,
        onContinue: _next,
      );
    } else if (_angle case final angle?) {
      body = PhotoStep(
        key: ValueKey(angle),
        type: type,
        angle: angle,
        photo: _photos[angle],
        busy: _busy,
        message: _message,
        onPick: (origin) => _pick(angle, origin),
        onRetake: () => _pick(angle, _lastOrigin[angle] ?? PhotoOrigin.camera),
        onContinue: _next,
        onSkip: () => _skip(angle),
      );
    } else {
      body = ReviewStep(
        key: const ValueKey('review'),
        event: event,
        type: type,
        photos: _photos,
        causes: [for (final c in reportCauses) if (_causes.contains(c)) c],
        explanation: _explanation.text.trim(),
        luthier: luthier,
        busy: false,
        onEditExplanation: () => _go(0),
        onOpenAngle: (angle) => _go(PhotoAngle.values.indexOf(angle) + 1),
        onSubmit: _submit,
      );
    }

    return PopScope(
      canPop: _sent || (_step == 0 && !_hasDraft),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: Motion.medium,
                child: _sent
                    ? const SizedBox(width: double.infinity)
                    : _ProgressHeader(
                        step: _step,
                        total: _stepCount,
                        label: switch (_angle) {
                          _ when _step == 0 => 'Document event',
                          final PhotoAngle a => a.short,
                          null => 'Review',
                        },
                        onBack: _step == 0 ? null : _back,
                        onClose: _close,
                      ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == body.key;
                    return FadeTransition(
                      opacity: animation,
                      child: incoming
                          ? SlideTransition(
                              position: Tween(begin: Offset(0.06 * _direction, 0), end: Offset.zero)
                                  .animate(animation),
                              child: child,
                            )
                          : child,
                    );
                  },
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back, a step count with its label, close, and a segmented hairline.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.step,
    required this.total,
    required this.label,
    required this.onBack,
    required this.onClose,
  });

  final int step;
  final int total;
  final String label;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.xs, 0),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedOpacity(
                opacity: onBack == null ? 0 : 1,
                duration: Motion.fast,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Eyebrow('Step ${step + 1} of $total'),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: Motion.fast,
                      child: Text(label, key: ValueKey(label), style: text.titleSmall),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.page - Space.xs),
            child: Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: Space.xs),
                  Expanded(
                    child: AnimatedContainer(
                      duration: Motion.slow,
                      curve: Motion.enter,
                      height: i == step ? 2 : 1.4,
                      decoration: BoxDecoration(
                        color: i <= step ? colors.accent : colors.hairline,
                        borderRadius: const BorderRadius.all(Radii.pill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
