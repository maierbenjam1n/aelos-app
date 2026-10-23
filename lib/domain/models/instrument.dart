/// Instrument family, stored by enum name in JSON.
enum InstrumentType {
  violin('Violin'),
  viola('Viola'),
  cello('Cello'),
  doubleBass('Double bass');

  const InstrumentType(this.label);

  /// English display name.
  final String label;

  /// Parses an enum name such as `doubleBass`.
  static InstrumentType fromName(String name) => values.byName(name);
}

/// A registered instrument and the sensor paired with it.
final class Instrument {
  const Instrument({
    required this.id,
    required this.name,
    required this.type,
    required this.yearMade,
    required this.topWood,
    required this.backWood,
    required this.varnish,
    required this.sensorId,
    required this.sensorPublicKey,
    this.maker,
    this.origin,
    this.era,
    this.crackRepairs = false,
    this.crackRepairNote,
    this.photo,
  });

  /// Reads the shape written by [toJson] and `tools/gen_seed.py`.
  factory Instrument.fromJson(Map<String, Object?> json) => Instrument(
        id: json['id']! as String,
        name: json['name']! as String,
        type: InstrumentType.fromName(json['type']! as String),
        maker: json['maker'] as String?,
        origin: json['origin'] as String?,
        yearMade: json['yearMade']! as int,
        era: json['era'] as String?,
        topWood: json['topWood']! as String,
        backWood: json['backWood']! as String,
        varnish: json['varnish']! as String,
        crackRepairs: json['crackRepairs'] as bool? ?? false,
        crackRepairNote: json['crackRepairNote'] as String?,
        photo: json['photo'] as String?,
        sensorId: json['sensorId']! as String,
        sensorPublicKey: json['sensorPublicKey']! as String,
      );

  /// Stable identifier, e.g. `violin-mittenwald`.
  final String id;

  /// Display name, e.g. "Violin, Mittenwald 1890".
  final String name;
  final InstrumentType type;

  /// Maker or workshop, e.g. "Mirecourt workshop".
  final String? maker;

  /// Place of making, e.g. "Mirecourt, Vosges".
  final String? origin;

  /// Best-known year of making; the threshold engine uses it for age rules.
  final int yearMade;

  /// Display form when the year is approximate, e.g. "c. 1860".
  final String? era;
  final String topWood;
  final String backWood;
  final String varnish;

  /// Whether the instrument has had cracks repaired; tightens rate limits.
  final bool crackRepairs;
  final String? crackRepairNote;

  /// Asset path or file path of the hero photo.
  final String? photo;

  /// Paired sensor's device ID, e.g. `1AFB`.
  final String sensorId;

  /// Paired sensor's raw Ed25519 public key, standard base64.
  final String sensorPublicKey;

  /// [era] if set, otherwise [yearMade].
  String get dateLabel => era ?? '$yearMade';

  /// Writes the shape read by [Instrument.fromJson].
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'maker': maker,
        'origin': origin,
        'yearMade': yearMade,
        'era': era,
        'topWood': topWood,
        'backWood': backWood,
        'varnish': varnish,
        'crackRepairs': crackRepairs,
        'crackRepairNote': crackRepairNote,
        'photo': photo,
        'sensorId': sensorId,
        'sensorPublicKey': sensorPublicKey,
      };

  @override
  bool operator ==(Object other) =>
      other is Instrument &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.maker == maker &&
      other.origin == origin &&
      other.yearMade == yearMade &&
      other.era == era &&
      other.topWood == topWood &&
      other.backWood == backWood &&
      other.varnish == varnish &&
      other.crackRepairs == crackRepairs &&
      other.crackRepairNote == crackRepairNote &&
      other.photo == photo &&
      other.sensorId == sensorId &&
      other.sensorPublicKey == sensorPublicKey;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        maker,
        origin,
        yearMade,
        era,
        topWood,
        backWood,
        varnish,
        crackRepairs,
        crackRepairNote,
        photo,
        sensorId,
        sensorPublicKey,
      );
}
