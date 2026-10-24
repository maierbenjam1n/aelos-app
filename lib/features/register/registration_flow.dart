import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/aelos_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/instruments_notifier.dart';
import '../../data/sensor_session.dart';
import '../../domain/models/device_info.dart';
import '../../domain/models/instrument.dart';
import '../../sensor/mock/mock_sensor_connection.dart';
import '../../sensor/mock/test_key.dart';
import '../../sensor/sensor_connection.dart';
import '../onboarding/onboarding_screen.dart';
import '../pairing/pairing_screen.dart';
import 'instrument_registration_screen.dart';

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
      OnboardingCompletedNotifier.new,
    );

class OnboardingCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markCompleted() => state = true;
}

enum _RegistrationStage { onboarding, preparing, pairing, registration, error }

/// Guides a new instrument from the introduction through pairing and registration.
class RegistrationFlow extends ConsumerStatefulWidget {
  const RegistrationFlow({super.key, required this.showOnboarding});

  final bool showOnboarding;

  @override
  ConsumerState<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends ConsumerState<RegistrationFlow> {
  late _RegistrationStage _stage = widget.showOnboarding
      ? _RegistrationStage.onboarding
      : _RegistrationStage.preparing;
  SensorConnection? _connection;
  DeviceInfo? _pairedInfo;
  String? _error;
  bool _connectionTransferred = false;

  @override
  void initState() {
    super.initState();
    if (!widget.showOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_preparePairing());
      });
    }
  }

  @override
  void dispose() {
    final connection = _connection;
    if (!_connectionTransferred && connection is MockSensorConnection) {
      unawaited(connection.dispose());
    } else if (!_connectionTransferred && connection != null) {
      unawaited(connection.disconnect());
    }
    super.dispose();
  }

  void _finishOnboarding() {
    ref.read(onboardingCompletedProvider.notifier).markCompleted();
    unawaited(_preparePairing());
  }

  Future<void> _preparePairing() async {
    setState(() {
      _stage = _RegistrationStage.preparing;
      _error = null;
    });
    try {
      final instruments = await ref.read(instrumentsProvider.future);
      final transport = ref.read(transportProvider);
      late final SensorConnection connection;
      if (transport == SensorTransport.mock) {
        final count = instruments
            .where((item) => item.id.startsWith('registered-'))
            .length;
        connection = MockSensorConnection(
          privateSeed: registrationTestKeySeed(count),
          readingInterval: MockSensorConnection.demoReadingInterval,
        );
      } else {
        connection = await ref.read(sensorConnectionProvider.future);
      }
      if (!mounted) {
        if (connection is MockSensorConnection) unawaited(connection.dispose());
        return;
      }
      setState(() {
        _connection = connection;
        _stage = _RegistrationStage.pairing;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ref.read(transportProvider) == SensorTransport.mock
            ? error.toString()
            : 'This build can pair mock sensors. WebSocket and Bluetooth pairing are still in progress.';
        _stage = _RegistrationStage.error;
      });
    }
  }

  void _onPaired(DeviceInfo info) => setState(() {
    _pairedInfo = info;
    _stage = _RegistrationStage.registration;
  });

  Future<void> _save(Instrument instrument, Uint8List? photoBytes) async {
    final connection = _connection;
    final info = _pairedInfo;
    if (connection == null || info == null) {
      throw StateError('Pair the sensor before adding the instrument');
    }

    final data = ref
        .read(instrumentsProvider.notifier)
        .register(instrument, photoBytes: photoBytes);
    _connectionTransferred = true;
    try {
      await ref
          .read(sessionProvider.notifier)
          .startPaired(data.id, connection, info);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Instrument added. Sensor session could not start: $error',
            ),
          ),
        );
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _RegistrationStage.onboarding => OnboardingScreen(
      onFinished: _finishOnboarding,
    ),
    _RegistrationStage.preparing => const _PreparingScreen(),
    _RegistrationStage.pairing => PairingScreen(
      connection: _connection!,
      onPaired: _onPaired,
    ),
    _RegistrationStage.registration => InstrumentRegistrationScreen(
      sensor: _pairedInfo!,
      onBack: () => setState(() => _stage = _RegistrationStage.pairing),
      onSave: _save,
    ),
    _RegistrationStage.error => _PairingUnavailableScreen(
      message: _error ?? 'The sensor could not be reached.',
      onRetry: _preparePairing,
      onClose: () => Navigator.of(context).pop(),
    ),
  };
}

class _PreparingScreen extends StatelessWidget {
  const _PreparingScreen();

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add an instrument')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.accent),
              const SizedBox(height: Space.l),
              Text('Preparing the sensor', style: text.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _PairingUnavailableScreen extends StatelessWidget {
  const _PairingUnavailableScreen({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to collection',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Add an instrument'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sensors_off_outlined,
                size: 42,
                color: colors.attention,
              ),
              const SizedBox(height: Space.l),
              Text('Could not prepare pairing', style: text.titleLarge),
              const SizedBox(height: Space.s),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: Space.xl),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
