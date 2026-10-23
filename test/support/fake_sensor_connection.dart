import 'dart:async';

import 'package:aelos/domain/models/device_info.dart';
import 'package:aelos/domain/models/live_reading.dart';
import 'package:aelos/domain/models/sensor_record.dart';
import 'package:aelos/sensor/sensor_connection.dart';

const testDeviceInfo = DeviceInfo(
  id: '1AFB',
  firmware: '0.1.0',
  publicKey: 'fhiI2SByZBXfx9MAx1+RpbDKd1MWhjk0bZybDneDA4A=',
);

/// Scripted [SensorConnection] for widget tests: emits [found] from `scan`
/// and answers `connect` with [info], or throws if [failConnect].
class FakeSensorConnection implements SensorConnection {
  FakeSensorConnection({
    this.found = const [DiscoveredSensor(id: 'a', name: 'Aelos-1AFB', rssi: -52)],
    this.info = testDeviceInfo,
    this.failConnect = false,
  });

  final List<DiscoveredSensor> found;
  final DeviceInfo info;
  final bool failConnect;
  final connected = <String>[];

  @override
  Stream<List<DiscoveredSensor>> scan() async* {
    yield [];
    await Future<void>.delayed(const Duration(milliseconds: 500));
    yield found;
  }

  @override
  Future<DeviceInfo> connect(String sensorId) async {
    connected.add(sensorId);
    if (failConnect) throw StateError('unreachable');
    return info;
  }

  @override
  Stream<ConnectionStatus> get status => const Stream.empty();

  @override
  Stream<LiveReading> get live => const Stream.empty();

  @override
  Stream<SensorRecord> get records => const Stream.empty();

  @override
  Future<void> sendTime(DateTime utcNow) async {}

  @override
  Future<void> sync(int fromSeq) async {}

  @override
  Future<void> sendDemoCommand(DemoCommand cmd) async {}

  @override
  Future<void> disconnect() async {}
}
