/// Sensor identity read from the `info` characteristic.
final class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.firmware,
    required this.publicKey,
  });

  factory DeviceInfo.fromJson(Map<String, Object?> json) => DeviceInfo(
        id: json['id']! as String,
        firmware: json['fw']! as String,
        publicKey: json['pk']! as String,
      );

  /// Four uppercase hex characters, e.g. `1AFB`; also in the name `Aelos-1AFB`.
  final String id;
  final String firmware;

  /// Raw Ed25519 public key, standard base64.
  final String publicKey;
}
