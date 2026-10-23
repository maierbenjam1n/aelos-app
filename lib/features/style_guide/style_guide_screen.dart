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
import '../../core/widgets/rise_in.dart';
import '../../core/widgets/status_badge.dart';
import '../../domain/models/condition_status.dart';

/// Every token and shared widget on one page, for design review.
class StyleGuideScreen extends ConsumerWidget {
  const StyleGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    final sections = <Widget>[
      _Header(colors: colors),
      const _Section('Instrument card', child: _SampleInstrumentCard()),
      _Section(
        'Live reading',
        child: AelosCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Relative humidity'),
              const SizedBox(height: Space.s),
              const ReadingValue(value: 48.2, unit: '%', size: ReadingSize.hero),
              const SizedBox(height: Space.m),
              Text(
                'Tighter limits applied: instrument over 100 years old',
                style: AelosText.of(context).note,
              ),
            ],
          ),
        ),
      ),
      _Section(
        'Status',
        child: Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final s in ConditionStatus.values) StatusBadge(s),
            for (final s in ConditionStatus.values) StatusBadge(s, large: true),
          ],
        ),
      ),
      _Section(
        'Type',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Condition passport', style: text.displayMedium),
            Text('Violin, Mittenwald 1890', style: text.headlineMedium),
            Text('While you were away', style: text.titleLarge),
            const SizedBox(height: Space.s),
            Text(
              'Humidity fell 6 % in the last hour. Keep the case closed and '
              'add a humidifier pack.',
              style: text.bodyLarge,
            ),
            Text('Last synced 2 minutes ago', style: text.bodySmall),
          ],
        ),
      ),
      const _Section(
        'Palette',
        child: Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            _Swatch('Walnut', AelosPalette.walnut),
            _Swatch('Ivory', AelosPalette.ivory),
            _Swatch('Varnish', AelosPalette.varnish),
            _Swatch('Sage', AelosPalette.sage),
            _Swatch('Amber', AelosPalette.amber),
            _Swatch('Oxblood', AelosPalette.oxblood),
          ],
        ),
      ),
      _Section(
        'Actions',
        child: Row(
          children: [
            Expanded(
              child: FilledButton(onPressed: () {}, child: const Text('Export passport')),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: OutlinedButton(onPressed: () {}, child: const Text('Verify')),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aelos'),
        actions: [
          IconButton(
            tooltip: 'Switch light and dark',
            icon: Icon(
              brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(brightness),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxxl),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.xxl),
        itemBuilder: (_, i) => sections[i].riseIn(i),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors});

  final AelosColors colors;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 168,
      child: Stack(
        children: [
          Positioned(
            right: Space.l,
            top: 0,
            child: FHole(height: 160, color: colors.accent.withValues(alpha: 0.3)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Eyebrow('Design system', color: colors.accentInk),
              const SizedBox(height: Space.s),
              Text('Quiet care for\nfine instruments', style: text.displayMedium),
              const SizedBox(height: Space.l),
              const Hairline(ornament: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(title),
          const SizedBox(height: Space.m),
          child,
        ],
      );
}

class _SampleInstrumentCard extends StatelessWidget {
  const _SampleInstrumentCard();

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return AelosCard(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Violin · 1890'),
                    const SizedBox(height: Space.xs),
                    Text('Mittenwald', style: text.headlineMedium),
                  ],
                ),
              ),
              const StatusBadge(ConditionStatus.calm),
            ],
          ),
          const SizedBox(height: Space.l),
          const Hairline(),
          const SizedBox(height: Space.l),
          const Row(
            children: [
              Expanded(child: _LabelledReading('Humidity', 48.2, '%')),
              Expanded(child: _LabelledReading('Temperature', 21.4, '°C')),
            ],
          ),
          const SizedBox(height: Space.l),
          Row(
            children: [
              Icon(Icons.bluetooth_connected_rounded, size: 16, color: colors.textFaint),
              const SizedBox(width: Space.xs + 2),
              Text('Synced 2 min ago', style: text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabelledReading extends StatelessWidget {
  const _LabelledReading(this.label, this.value, this.unit);

  final String label;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: Space.s),
          ReadingValue(value: value, unit: unit),
        ],
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(Radii.s),
              border: Border.all(color: colors.hairline, width: 0.8),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(name, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
