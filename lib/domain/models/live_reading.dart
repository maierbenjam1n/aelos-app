/// An unsigned current reading from the `live` characteristic.
final class LiveReading {
  const LiveReading({
    required this.tenthsCelsius,
    required this.tenthsHumidity,
    required this.time,
  });

  factory LiveReading.fromJson(Map<String, Object?> json) => LiveReading(
        tenthsCelsius: json['t']! as int,
        tenthsHumidity: json['h']! as int,
        time: DateTime.fromMillisecondsSinceEpoch(
          (json['ts']! as int) * 1000,
          isUtc: true,
        ),
      );

  final int tenthsCelsius;
  final int tenthsHumidity;
  final DateTime time;

  double get celsius => tenthsCelsius / 10;
  double get humidity => tenthsHumidity / 10;
}
