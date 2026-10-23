import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/aelos_card.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/rise_in.dart';
import '../../domain/models/device_info.dart';
import '../../sensor/sensor_connection.dart';
import 'pairing_controller.dart';
import 'scanning_halo.dart';

/// Hero moment: find the sensor, link it, show the key it signs with.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key, required this.connection, required this.onPaired});

  final SensorConnection connection;
  final void Function(DeviceInfo info) onPaired;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  late final _controller = PairingController(widget.connection);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, state, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Space.xl),
                const Center(child: Eyebrow('Pair a sensor')),
                // Halo and heading sit centred in the upper part of the screen;
                // the lower part has fixed slots so nothing jumps between states.
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScanningHalo(size: 280, active: state is! Paired),
                      const SizedBox(height: Space.xl),
                      _Heading(state),
                    ],
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: _Body(state: state, controller: _controller),
                ),
                SizedBox(
                  height: 52 + Space.l,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: switch (state) {
                      Paired(:final info) => SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => widget.onPaired(info),
                            child: const Text('Continue'),
                          ),
                        ).riseIn(2),
                      PairingFailed() => SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _controller.retry,
                            child: const Text('Try again'),
                          ),
                        ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
                const SizedBox(height: Space.s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.state);

  final PairingState state;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (title, subtitle) = switch (state) {
      Scanning(found: []) => (
          'Looking for your sensor',
          'Keep the phone close to the instrument case.',
        ),
      Scanning() => ('Sensor found', 'Tap it to link it to this phone.'),
      Connecting(:final sensor) => ('Linking ${sensor.name}', 'Reading its identity'),
      Paired(:final sensor) => ('Linked', '${sensor.name} is ready.'),
      PairingFailed(:final message) => ('Not linked', message),
    };
    return AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      child: Column(
        key: ValueKey(title),
        children: [
          Text(title, style: text.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: Space.s),
          Text(
            subtitle,
            style: text.bodyLarge!.copyWith(color: AelosColors.of(context).textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final PairingState state;
  final PairingController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: switch (state) {
        Scanning(:final found) => ListView.separated(
            key: const ValueKey('found'),
            itemCount: found.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.m),
            itemBuilder: (_, i) => _SensorCard(
              sensor: found[i],
              onTap: () => controller.connect(found[i]),
            ).riseIn(i),
          ),
        Connecting() => const Padding(
            key: ValueKey('connecting'),
            padding: EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.s),
            child: LinearProgressIndicator(minHeight: 1.2),
          ),
        Paired(:final info) => _KeyCard(info: info).riseIn(1),
        PairingFailed() => const SizedBox.shrink(key: ValueKey('failed')),
      },
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({required this.sensor, required this.onTap});

  final DiscoveredSensor sensor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final bars = switch (sensor.rssi) {
      null => 2,
      > -60 => 3,
      > -75 => 2,
      _ => 1,
    };
    return AelosCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.accent, width: 0.9),
            ),
            child: Icon(Icons.sensors_rounded, size: 20, color: colors.accent),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sensor.name, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  ['Weak signal', 'Good signal', 'Strong signal'][bars - 1],
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          _SignalBars(bars: bars, color: colors.accent, faint: colors.hairline),
          const SizedBox(width: Space.m),
          Icon(Icons.chevron_right_rounded, color: colors.textFaint),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.bars, required this.color, required this.faint});

  final int bars;
  final Color color;
  final Color faint;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(
              width: 3,
              height: 6.0 + 5 * i,
              decoration: BoxDecoration(
                color: i < bars ? color : faint,
                borderRadius: const BorderRadius.all(Radius.circular(1.5)),
              ),
            ),
          ],
        ],
      );
}

class _KeyCard extends StatelessWidget {
  const _KeyCard({required this.info});

  final DeviceInfo info;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topCenter,
      child: AelosCard(
        child: Column(
          children: [
            const Eyebrow('Signature key'),
            const SizedBox(height: Space.m),
            Text(
              keyFingerprint(info.publicKey),
              style: AelosText.of(context).readingSmall.copyWith(letterSpacing: 1.6),
            ),
            const SizedBox(height: Space.m),
            Text(
              'Every record this sensor writes is signed with this key, so its '
              'history can be verified by anyone you share it with.',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.s),
            Text(
              'Firmware ${info.firmware}',
              style: text.bodySmall!.copyWith(color: colors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
