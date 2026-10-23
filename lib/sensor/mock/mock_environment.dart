import 'dart:math';

/// One simulated measurement in protocol units (tenths of °C and % RH).
typedef MockSample = ({int tenthsCelsius, int tenthsHumidity});

/// Simulated climate inside the case: a day/night temperature cycle
/// (18–23 °C), humidity drifting slowly within 45–52 %, and the `dry` demo
/// scenario. Deterministic for a given [Random] and sequence of calls.
final class MockEnvironment {
  /// Draws the drift phases and all noise from [random].
  MockEnvironment(this._random)
    : _phaseA = _random.nextDouble() * 2 * pi,
      _phaseB = _random.nextDouble() * 2 * pi;

  final Random _random;
  final double _phaseA;
  final double _phaseB;

  // Percent RH per minute while drying, and while recovering after `normal`.
  static const _dryRate = 1.5;
  static const _recoverRate = 3.0;
  static const _dryFloor = 30.0;

  DateTime? _dryStart;
  double _dryFrom = 0;
  DateTime? _recoverStart;
  double _recoverFrom = 0;

  /// Whether the `dry` scenario is running.
  bool get isDrying => _dryStart != null;

  /// Starts the `dry` scenario at [at]; no effect if already drying.
  void startDrying(DateTime at) {
    if (_dryStart != null) return;
    _dryFrom = _humidity(at);
    _dryStart = at;
    _recoverStart = null;
  }

  /// Ends any scenario at [at]; humidity climbs back to normal over a few
  /// minutes instead of jumping.
  void endSimulations(DateTime at) {
    if (_dryStart == null) return;
    _recoverFrom = _humidity(at);
    _recoverStart = at;
    _dryStart = null;
  }

  /// A noisy measurement at [at] (local time sets the day/night cycle).
  MockSample sample(DateTime at) {
    final noisyT = _temperature(at) * 10 + _random.nextInt(3) - 1;
    final noisyH = _humidity(at) * 10 + _random.nextInt(5) - 2;
    final simulating = _dryStart != null || _recoverStart != null;
    return (
      tenthsCelsius: noisyT.round().clamp(180, 230),
      tenthsHumidity: noisyH.round().clamp(simulating ? 300 : 450, 520),
    );
  }

  // Coolest at 03:00, warmest at 15:00.
  double _temperature(DateTime at) {
    final local = at.toLocal();
    final hour = local.hour + local.minute / 60 + local.second / 3600;
    return 20.5 + 2.5 * cos(2 * pi * (hour - 15) / 24);
  }

  double _humidity(DateTime at) {
    final dryStart = _dryStart;
    if (dryStart != null) {
      final minutes = at.difference(dryStart).inMilliseconds / 60000;
      return max(_dryFloor, _dryFrom - _dryRate * minutes);
    }
    final base = _baseHumidity(at);
    final recoverStart = _recoverStart;
    if (recoverStart != null) {
      final minutes = at.difference(recoverStart).inMilliseconds / 60000;
      final recovered = _recoverFrom + _recoverRate * minutes;
      if (recovered < base) return recovered;
      _recoverStart = null;
    }
    return base;
  }

  // Two slow, incommensurate waves: 48.5 ± 3.2 %, never periodic-looking.
  double _baseHumidity(DateTime at) {
    final hours = at.millisecondsSinceEpoch / 3.6e6;
    return 48.5 +
        2.2 * sin(2 * pi * hours / 7 + _phaseA) +
        1.0 * sin(2 * pi * hours / 2.3 + _phaseB);
  }
}
