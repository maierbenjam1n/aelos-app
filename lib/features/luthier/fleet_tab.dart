import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/rise_in.dart';
import '../../data/sensor_session.dart';
import 'fleet_instrument_screen.dart';
import 'luthier_fleet.dart';
import 'luthier_widgets.dart';

enum _Filter { all, out, workshop }

/// Every instrument in the workshop's care, rented out first.
class FleetTab extends ConsumerStatefulWidget {
  const FleetTab({super.key});

  @override
  ConsumerState<FleetTab> createState() => _FleetTabState();
}

class _FleetTabState extends ConsumerState<FleetTab> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetProvider);
    final liveId = ref.watch(liveFleetIdProvider);
    final live = ref.watch(sessionProvider)?.live;
    final out = [for (final e in fleet) if (!e.inWorkshop) e];
    final workshop = [for (final e in fleet) if (e.inWorkshop) e];

    Widget card(FleetEntry e) => Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: FleetCard(
            entry: e,
            detailed: true,
            live: e.id == liveId,
            liveHumidity: e.id == liveId ? live?.humidity : null,
            onTap: () => FleetInstrumentScreen.open(context, e.id),
          ),
        );

    var i = 0;
    return LuthierPage(
      children: [
        PageHeading(
          eyebrow: 'In your care',
          title: 'The fleet',
          subtitle: '${out.length} rented out · ${workshop.length} in the workshop',
        ).riseIn(i++),
        const SizedBox(height: Space.xl),
        LuthierSegmented<_Filter>(
          segments: [
            (_Filter.all, 'All · ${fleet.length}'),
            (_Filter.out, 'Rented · ${out.length}'),
            (_Filter.workshop, 'Workshop · ${workshop.length}'),
          ],
          selected: _filter,
          onChanged: (f) => setState(() => _filter = f),
        ).riseIn(i++),
        const SizedBox(height: Space.xl),
        if (_filter != _Filter.workshop) ...[
          SectionHeader('Rented out', count: out.length).riseIn(i++),
          if (out.isEmpty) const LuthierEmpty('Nothing is rented out at the moment.'),
          for (final e in out) card(e).riseIn(i++),
          const SizedBox(height: Space.l),
        ],
        if (_filter != _Filter.out) ...[
          SectionHeader('In the workshop', count: workshop.length).riseIn(i++),
          if (workshop.isEmpty) const LuthierEmpty('Every instrument is out with a renter.'),
          for (final e in workshop) card(e).riseIn(i++),
        ],
      ],
    );
  }
}
