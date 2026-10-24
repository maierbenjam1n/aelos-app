import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/hairline.dart';
import '../../data/accounts.dart';
import 'demo_renters.dart';
import 'luthier_fleet.dart';
import 'luthier_format.dart';
import 'luthier_widgets.dart';

/// Who has the instrument, on what terms, and how to reach them; assign or
/// take it back.
class RentalPanel extends ConsumerWidget {
  const RentalPanel({super.key, required this.entry});

  final FleetEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final rental = entry.rental;
    final contact = DemoRenters.byId(rental.renterId);

    if (rental.inWorkshop) {
      return AelosCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.handyman_outlined, size: 18, color: colors.accent),
                const SizedBox(width: Space.s),
                const Eyebrow('In the workshop'),
              ],
            ),
            const SizedBox(height: Space.m),
            Text('Ready to rent', style: text.headlineSmall),
            const SizedBox(height: Space.xs),
            Text(
              'The sensor keeps recording on the bench, so the history continues unbroken '
              'when the next renter takes it home.',
              style: text.bodySmall,
            ),
            const SizedBox(height: Space.l),
            const Hairline(),
            const SizedBox(height: Space.m),
            _InfoRow(label: 'Offered as', value: rental.plan ?? 'Monthly rental'),
            const SizedBox(height: Space.l),
            FilledButton.icon(
              onPressed: () => showAssignSheet(context, entry),
              icon: const Icon(Icons.person_add_alt_rounded, size: 20),
              label: const Text('Assign to renter'),
            ),
          ],
        ),
      );
    }

    final name = rental.renterName ?? contact?.name ?? 'Renter';
    final since = rental.since?.toLocal();
    return AelosCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('Rented to'),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Monogram(name, size: 48, filled: true),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.headlineSmall),
                    if (contact != null) Text(contact.note, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          const Hairline(),
          const SizedBox(height: Space.m),
          _InfoRow(label: 'Plan', value: rental.plan ?? 'Monthly rental'),
          if (since != null)
            _InfoRow(
              label: 'Since',
              value: '${LuthierFormat.date(since)} · ${LuthierFormat.span(since)}',
            ),
          if (contact != null) ...[
            _InfoRow(label: 'Email', value: contact.email),
            _InfoRow(label: 'Phone', value: contact.phone, tabular: true),
          ],
          const SizedBox(height: Space.l),
          OutlinedButton.icon(
            onPressed: () => showReturnSheet(context, entry),
            icon: Icon(Icons.home_repair_service_outlined, size: 20, color: colors.accent),
            label: const Text('Return to workshop'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.tabular = false});

  final String label;
  final String value;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs + 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: text.bodySmall)),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium!.copyWith(
                fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AelosColors.of(context).surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radii.l)),
      builder: (_) => child,
    );

/// Choose one of the workshop's renters for an instrument in the workshop.
Future<void> showAssignSheet(BuildContext context, FleetEntry entry) =>
    _sheet(context, _AssignSheet(entry: entry));

/// Confirm ending the rental.
Future<void> showReturnSheet(BuildContext context, FleetEntry entry) =>
    _sheet(context, _ReturnSheet(entry: entry));

class _AssignSheet extends ConsumerStatefulWidget {
  const _AssignSheet({required this.entry});

  final FleetEntry entry;

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> {
  RenterContact? _chosen;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final renting = {for (final r in ref.watch(rentalsProvider)) if (r.renterId != null) r.renterId};
    final free = [for (final r in DemoRenters.all) if (!renting.contains(r.id)) r];
    final name = widget.entry.data.instrument.name;

    void assign() {
      final chosen = _chosen;
      if (chosen == null) return;
      ref
          .read(rentalsProvider.notifier)
          .assign(widget.entry.id, renterId: chosen.id, renterName: chosen.name);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('$name is now with ${chosen.name}.')));
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('Assign · $name', color: colors.accentInk),
                  const SizedBox(height: Space.s),
                  Text('Who is taking it home?', style: text.headlineMedium),
                  const SizedBox(height: Space.xs),
                  Text(
                    'The renter sees its climate and alerts on their phone from today.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: Space.page),
                children: [
                  for (final r in free)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      child: _RenterOption(
                        renter: r,
                        selected: _chosen?.id == r.id,
                        onTap: () => setState(() => _chosen = r),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, Space.l),
              child: FilledButton(
                onPressed: _chosen == null ? null : assign,
                child: Text(_chosen == null ? 'Choose a renter' : 'Assign to ${_chosen!.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenterOption extends StatelessWidget {
  const _RenterOption({required this.renter, required this.selected, required this.onTap});

  final RenterContact renter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: selected ? colors.accent.withValues(alpha: 0.10) : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radii.m),
        side: BorderSide(color: selected ? colors.accent : colors.hairline, width: selected ? 1.2 : 0.8),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radii.m),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Row(
            children: [
              Monogram(renter.name, size: 40),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(renter.name, style: text.titleMedium),
                    Text(renter.note, style: text.bodySmall),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: Motion.fast,
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? colors.accent : colors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnSheet extends ConsumerWidget {
  const _ReturnSheet({required this.entry});

  final FleetEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final name = entry.data.instrument.name;
    final renter = entry.rental.renterName ?? 'the renter';

    void confirm() {
      ref.read(rentalsProvider.notifier).returnToWorkshop(entry.id);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('$name is back in the workshop.')));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Eyebrow('Return · $name', color: colors.accentInk),
            const SizedBox(height: Space.s),
            Text('Back to the workshop?', style: text.headlineMedium),
            const SizedBox(height: Space.s),
            Text(
              'The rental with $renter ends today. The sensor stays with the instrument, '
              'so its signed history continues without a break.',
              style: text.bodyMedium!.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: Space.l),
            Text(
              'Worth a look on the bench: the seams, the bridge and the soundpost.',
              style: AelosText.of(context).note,
            ),
            const SizedBox(height: Space.xl),
            FilledButton(onPressed: confirm, child: const Text('Return to workshop')),
            const SizedBox(height: Space.s),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Keep the rental')),
          ],
        ),
      ),
    );
  }
}
