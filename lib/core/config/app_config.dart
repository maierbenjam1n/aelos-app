enum SensorTransport { mock, ws, ble }

/// Build-time configuration from `--dart-define`.
abstract final class AppConfig {
  static const _sensor = String.fromEnvironment('SENSOR', defaultValue: 'mock');

  /// Initial transport; the demo panel can switch it at runtime.
  static final SensorTransport initialTransport = SensorTransport.values
      .firstWhere((t) => t.name == _sensor, orElse: () => SensorTransport.mock);

  static const piHost = String.fromEnvironment('PI_HOST', defaultValue: 'aelos.local');
  static const piPort = 8765;
}
