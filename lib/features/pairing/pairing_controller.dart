import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/models/device_info.dart';
import '../../sensor/sensor_connection.dart';

sealed class PairingState {
  const PairingState();
}

final class Scanning extends PairingState {
  const Scanning(this.found);
  final List<DiscoveredSensor> found;
}

final class Connecting extends PairingState {
  const Connecting(this.sensor);
  final DiscoveredSensor sensor;
}

final class Paired extends PairingState {
  const Paired(this.sensor, this.info);
  final DiscoveredSensor sensor;
  final DeviceInfo info;
}

final class PairingFailed extends PairingState {
  const PairingFailed(this.message);
  final String message;
}

/// Scan → pick → connect, over whichever transport is active.
class PairingController extends ValueNotifier<PairingState> {
  PairingController(this._connection) : super(const Scanning([])) {
    _startScan();
  }

  final SensorConnection _connection;
  StreamSubscription<List<DiscoveredSensor>>? _scan;

  void _startScan() {
    value = const Scanning([]);
    _scan = _connection.scan().listen(
      (found) {
        if (value is Scanning) value = Scanning(found);
      },
      onError: (Object _) => value = const PairingFailed(
        'Bluetooth is not available. Check that it is switched on.',
      ),
    );
  }

  Future<void> connect(DiscoveredSensor sensor) async {
    // Stopping a BLE scan can take a moment; don't hold the UI for it.
    unawaited(_scan?.cancel());
    value = Connecting(sensor);
    try {
      // Keep the connecting state on screen long enough to read.
      final (info, _) = await (
        _connection.connect(sensor.id),
        Future<void>.delayed(const Duration(milliseconds: 900)),
      ).wait;
      value = Paired(sensor, info);
    } on Object {
      value = PairingFailed('Could not reach ${sensor.name}. Bring the phone closer and try again.');
    }
  }

  void retry() {
    unawaited(_scan?.cancel());
    _startScan();
  }

  @override
  void dispose() {
    unawaited(_scan?.cancel());
    super.dispose();
  }
}

/// First 8 bytes of the public key as four groups, e.g. `7E18 88D9 2072 6415`.
String keyFingerprint(String publicKeyBase64) {
  final bytes = base64Decode(publicKeyBase64).take(8).toList();
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  return [for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4)].join(' ');
}
