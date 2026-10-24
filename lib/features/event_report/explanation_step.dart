import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/rise_in.dart';
import 'report_copy.dart';

/// Step one: what happened, in quick answers and in the person's own words.
class ExplanationStep extends StatelessWidget {
  const ExplanationStep({
    super.key,
    required this.event,
    required this.causes,
    required this.onToggleCause,
    required this.controller,
    required this.onContinue,
  });

  final EventSummary event;
  final Set<String> causes;
  final ValueChanged<String> onToggleCause;
  final TextEditingController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AelosColors.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What happened?', style: text.displaySmall).riseIn(0),
                const SizedBox(height: Space.s),
                Text(
                  'A few words now make the signed record meaningful later, '
                  'for you and for whoever looks at the instrument next.',
                  style: text.bodyMedium!.copyWith(color: colors.textMuted),
                ).riseIn(1),
                const SizedBox(height: Space.xl),
                EventSummaryCard(event: event).riseIn(2),
                const SizedBox(height: Space.xxl),
                const Eyebrow('Quick answers').riseIn(3),
                const SizedBox(height: Space.m),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final cause in reportCauses)
                      CauseChip(
                        label: cause,
                        selected: causes.contains(cause),
                        onTap: () => onToggleCause(cause),
                      ),
                  ],
                ).riseIn(4),
                const SizedBox(height: Space.xxl),
                const Eyebrow('In your own words').riseIn(5),
                const SizedBox(height: Space.s),
                _RuledNote(controller: controller).riseIn(6),
              ],
            ),
          ),
        ),
        StepActions(
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => FilledButton(
                onPressed: onContinue,
                child: Text(
                  causes.isEmpty && controller.text.trim().isEmpty ? 'Continue without notes' : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// What is being documented, shown at the top of the flow.
class EventSummary {
  const EventSummary({
    required this.title,
    required this.when,
    required this.instrumentName,
    this.seq,
  });

  final String title;

  /// Already formatted display time, e.g. "Today · 14:32".
  final String when;
  final String instrumentName;
  final int? seq;
}

/// The signed event as a quiet card: value large, headline, instrument and time.
class EventSummaryCard extends StatelessWidget {
  const EventSummaryCard({super.key, required this.event, this.compact = false});

  final EventSummary event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = AelosColors.of(context);
    final type = AelosText.of(context);
    final parts = splitEventTitle(event.title);
    return AelosCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 14, color: colors.accent),
                    const SizedBox(width: Space.xs + 2),
                    Flexible(
                      child: Eyebrow(
                        event.seq == null ? 'Signed record' : 'Signed record · No. ${event.seq}',
                        color: colors.accentInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s),
                Text(parts.headline, style: compact ? text.titleLarge : text.headlineSmall),
                const SizedBox(height: Space.xs),
                Text(
                  '${event.instrumentName} · ${event.when}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (parts.number != null) ...[
            const SizedBox(width: Space.m),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: parts.number, style: compact ? type.readingSmall : type.readingLarge),
                  if (parts.unit != null) ...[
                    const WidgetSpan(child: SizedBox(width: Space.xs)),
                    TextSpan(text: parts.unit, style: type.unit),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A pill that fills with varnish when chosen; check mark slides in.
class CauseChip extends StatelessWidget {
  const CauseChip({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    const radius = BorderRadius.all(Radii.pill);
    return Semantics(
      selected: selected,
      button: onTap != null,
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.enter,
        decoration: BoxDecoration(
          color: selected ? colors.accent.withValues(alpha: 0.14) : colors.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? colors.accent : colors.hairline,
            width: selected ? 1 : 0.8,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.l - 2, vertical: Space.s + 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: Motion.medium,
                    curve: Motion.enter,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(right: Space.xs + 2),
                            child: Icon(Icons.check_rounded, size: 16, color: colors.accentInk),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Text(
                    label,
                    style: text.labelLarge!.copyWith(
                      color: selected ? colors.accentInk : colors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A multi-line field on ruled lines, written in the serif, like a note in
/// a workshop ledger rather than a form box.
class _RuledNote extends StatelessWidget {
  const _RuledNote({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final base = Theme.of(context).textTheme.titleLarge!;
    final style = base.copyWith(fontWeight: FontWeight.w400, height: 1.5, color: colors.text);
    final lineHeight = style.fontSize! * style.height!;
    return CustomPaint(
      painter: _RulePainter(lineHeight: lineHeight, color: colors.hairline),
      child: TextField(
        controller: controller,
        minLines: 5,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: colors.accent,
        cursorWidth: 1.5,
        style: style,
        strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
        scrollPadding: const EdgeInsets.only(bottom: Space.xxxl * 2),
        decoration: InputDecoration.collapsed(
          hintText: 'The case slipped off my shoulder on the stairs; '
              'it landed on its side…',
          hintStyle: style.copyWith(
            color: colors.textFaint,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _RulePainter extends CustomPainter {
  const _RulePainter({required this.lineHeight, required this.color});

  final double lineHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    // Sits each line just under the text's baseline.
    for (var y = lineHeight * 0.86; y <= size.height + 1; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) => old.lineHeight != lineHeight || old.color != color;
}

/// The pinned action area at the foot of every step, above a hairline.
class StepActions extends StatelessWidget {
  const StepActions({super.key, required this.children, this.above});

  final List<Widget> children;

  /// An optional calm message shown above the buttons.
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.hairline, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, Space.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                duration: Motion.medium,
                curve: Motion.enter,
                alignment: Alignment.topCenter,
                child: above == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(padding: const EdgeInsets.only(bottom: Space.m), child: above),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
