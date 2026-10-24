import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/hairline.dart';
import '../../data/instruments_notifier.dart';
import '../../data/sensor_session.dart';
import '../../sensor/sensor_connection.dart';

/// The instrument the demo's live sensor belongs to.
const demoInstrumentId = 'violin-mittenwald';

/// Backstage controls, opened by long-pressing the logo. Everything here must
/// work on the first tap during a live demo.
Future<void> showDemoPanel(
  BuildContext context, {
  required VoidCallback onOpenStyleGuide,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: AelosColors.of(context).surfaceRaised,
  builder: (_) => DemoPanel(onOpenStyleGuide: onOpenStyleGuide),
);

class DemoPanel extends ConsumerWidget {
  const DemoPanel({super.key, required this.onOpenStyleGuide});

  final VoidCallback onOpenStyleGuide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider);
    final mock = ref.watch(sessionProvider.notifier).mock;
    final transport = ref.watch(transportProvider);
    final connected =
        session?.status == ConnectionStatus.connected ||
        session?.status == ConnectionStatus.syncing;

    void close() => Navigator.of(context).pop();
    Future<void> demo(DemoAction action) async {
      close();
      await mock?.sendDemoCommand(DemoCommand(action));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Demo controls', style: text.headlineSmall),
            const SizedBox(height: Space.xs),
            Text(
              session == null
                  ? 'No live sensor yet. Pair one, or reset the demo.'
                  : 'Live sensor: ${session.status.name}${mock == null ? '' : ' · mock'}',
              style: text.bodySmall,
            ),
            const SizedBox(height: Space.l),
            const Eyebrow('Events'),
            const SizedBox(height: Space.s),
            _Grid(
              children: [
                _Action(
                  'Impact',
                  Icons.flash_on_rounded,
                  mock == null ? null : () => demo(DemoAction.impact),
                ),
                _Action(
                  'Free fall',
                  Icons.south_rounded,
                  mock == null ? null : () => demo(DemoAction.freefall),
                ),
                _Action(
                  mock?.isDrying ?? false ? 'Stop drying' : 'Drying trend',
                  Icons.water_drop_outlined,
                  mock == null
                      ? null
                      : () => demo(
                          mock.isDrying ? DemoAction.normal : DemoAction.dry,
                        ),
                ),
                _Action(
                  connected ? 'Disconnect' : 'Reconnect',
                  connected
                      ? Icons.bluetooth_disabled_rounded
                      : Icons.bluetooth_connected_rounded,
                  mock == null
                      ? null
                      : () {
                          close();
                          connected
                              ? mock.simulateDisconnect()
                              : mock.simulateReconnect();
                        },
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            const Eyebrow('Transport'),
            const SizedBox(height: Space.s),
            SegmentedButton<SensorTransport>(
              segments: const [
                ButtonSegment(value: SensorTransport.mock, label: Text('Mock')),
                ButtonSegment(
                  value: SensorTransport.ws,
                  label: Text('Wi-Fi'),
                  enabled: false,
                ),
                ButtonSegment(
                  value: SensorTransport.ble,
                  label: Text('Bluetooth'),
                  enabled: false,
                ),
              ],
              selected: {transport},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(transportProvider.notifier).set(s.single),
            ),
            const SizedBox(height: Space.xl),
            const Hairline(),
            const SizedBox(height: Space.m),
            _Row(
              'Reset to seeded data',
              'Fresh history, live sensor reconnected',
              Icons.restart_alt_rounded,
              () async {
                close();
                await resetDemoData(ref);
              },
            ),
            _Row(
              'Style guide',
              'Every token and component',
              Icons.palette_outlined,
              () {
                close();
                onOpenStyleGuide();
              },
            ),
            const SizedBox(height: Space.s),
            Text(
              'Long-press the Aelos mark to open this panel.',
              style: text.bodySmall!.copyWith(color: colors.textFaint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Throws away all live state and starts again from the seed, with the mock
/// sensor reconnected to the demo instrument.
Future<void> resetDemoData(WidgetRef ref) async {
  ref.read(awaySummaryProvider.notifier).dismiss();
  ref
    ..invalidate(sessionProvider)
    ..invalidate(sensorConnectionProvider)
    ..invalidate(appStartProvider)
    ..invalidate(instrumentsProvider);
  await ref.read(instrumentsProvider.future);
  await ref.read(sessionProvider.notifier).start(demoInstrumentId);
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: Space.s,
    crossAxisSpacing: Space.s,
    childAspectRatio: 3.2,
    children: children,
  );
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(minimumSize: Size.zero),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.title, this.subtitle, this.icon, this.onTap);

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    onTap: onTap,
  );
}
