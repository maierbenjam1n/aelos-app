import '../domain/models/device_info.dart';
import '../domain/models/live_reading.dart';
import '../domain/models/sensor_record.dart';

/// A sensor found while scanning. [id] is transport-specific and only
/// meaningful to the [SensorConnection] that produced it.
final class DiscoveredSensor {
  const DiscoveredSensor({required this.id, required this.name, this.rssi});

  final String id;
  final String name;
  final int? rssi;
}

enum ConnectionStatus { scanning, connecting, connected, syncing, disconnected }

enum DemoAction { impact, freefall, dry, normal }

/// A `{"cmd":"demo"}` control command (docs/ble-protocol.md 4.3).
final class DemoCommand {
  const DemoCommand(this.action, {this.tenthsG, this.freeFallMs});

  final DemoAction action;
  final int? tenthsG;
  final int? freeFallMs;

  Map<String, Object> toJson() => {
        'cmd': 'demo',
        'do': action.name,
        if (tenthsG != null) 'g': tenthsG!,
        if (freeFallMs != null) 'ms': freeFallMs!,
      };
}

/// The one interface the app uses to talk to a sensor; BLE, WebSocket and
/// mock transports implement it so screens never know which is active.
abstract interface class SensorConnection {
  Stream<List<DiscoveredSensor>> scan();

  /// Runs the connection sequence of docs/ble-protocol.md 3.1 up to reading
  /// `info`. Records start flowing after [sync].
  Future<DeviceInfo> connect(String sensorId);

  Stream<ConnectionStatus> get status;

  Stream<LiveReading> get live;

  /// Replayed records from [sync]'s `fromSeq`, then new ones in real time.
  Stream<SensorRecord> get records;

  Future<void> sendTime(DateTime utcNow);

  /// Asks the sensor to deliver every record with `s >= fromSeq`.
  Future<void> sync(int fromSeq);

  Future<void> sendDemoCommand(DemoCommand cmd);

  Future<void> disconnect();
}
