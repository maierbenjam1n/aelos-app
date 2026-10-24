import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../history/gaps.dart';
import '../models/instrument.dart';
import '../models/sensor_record.dart';
import '../verification/chain_verifier.dart';

const _passportFormat = 'aelos/1';
const _maxBundleBytes = 50 * 1024 * 1024;
const _maxRecordsBytes = 20 * 1024 * 1024;
const _maxPhotoBytes = 8 * 1024 * 1024;

/// The manifest for a portable Aelos condition history.
final class PassportManifest {
  const PassportManifest({
    required this.deviceId,
    required this.publicKey,
    required this.instrument,
    required this.from,
    required this.to,
    required this.firstSeq,
    required this.lastSeq,
    required this.prevOfFirst,
    required this.recordCount,
    this.photoFile,
  });

  final String deviceId;
  final String publicKey;
  final Instrument instrument;
  final DateTime from;
  final DateTime to;
  final int firstSeq;
  final int lastSeq;
  final Uint8List prevOfFirst;
  final int recordCount;
  final String? photoFile;

  Map<String, Object?> toJson() => {
    'format': _passportFormat,
    'device': {'id': deviceId},
    'public_key': publicKey,
    'instrument': instrument.toJson(),
    'range': {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    },
    'first_seq': firstSeq,
    'last_seq': lastSeq,
    'prev_of_first': base64Encode(prevOfFirst),
    'record_count': recordCount,
    if (photoFile != null) 'photo_file': photoFile,
  };

  factory PassportManifest.fromJson(Map<String, Object?> json) {
    if (json['format'] != _passportFormat) {
      throw const FormatException('Unsupported Aelos passport format');
    }
    final device = json['device'];
    final range = json['range'];
    final rawInstrument = json['instrument'];
    if (device is! Map<String, Object?> ||
        range is! Map<String, Object?> ||
        rawInstrument is! Map<String, Object?>) {
      throw const FormatException(
        'Passport manifest is missing required sections',
      );
    }

    final deviceId = device['id'];
    final publicKey = json['public_key'];
    final rangeFrom = range['from'];
    final rangeTo = range['to'];
    final firstSeq = json['first_seq'];
    final lastSeq = json['last_seq'];
    final recordCount = json['record_count'];
    final encodedPrev = json['prev_of_first'];
    final photoFile = json['photo_file'];
    if (deviceId is! String ||
        publicKey is! String ||
        rangeFrom is! String ||
        rangeTo is! String ||
        firstSeq is! int ||
        lastSeq is! int ||
        recordCount is! int ||
        encodedPrev is! String ||
        (photoFile != null && photoFile is! String)) {
      throw const FormatException('Passport manifest has invalid field types');
    }

    final from = DateTime.tryParse(rangeFrom);
    final to = DateTime.tryParse(rangeTo);
    final prev = _decodeBase64(encodedPrev, 'previous record hash');
    final instrument = Instrument.fromJson(rawInstrument);
    if (from == null || to == null || !from.isBefore(to)) {
      throw const FormatException('Passport date range is invalid');
    }
    if (prev.length != 32 ||
        firstSeq < 1 ||
        lastSeq < firstSeq ||
        recordCount < 1) {
      throw const FormatException('Passport sequence range is invalid');
    }
    if (deviceId != instrument.sensorId ||
        publicKey != instrument.sensorPublicKey) {
      throw const FormatException(
        'Passport sensor identity does not match its profile',
      );
    }
    if (photoFile is String &&
        (photoFile.contains('/') ||
            photoFile.contains('\\') ||
            photoFile == '..')) {
      throw const FormatException('Passport photo path is invalid');
    }

    return PassportManifest(
      deviceId: deviceId,
      publicKey: publicKey,
      instrument: instrument,
      from: from.toUtc(),
      to: to.toUtc(),
      firstSeq: firstSeq,
      lastSeq: lastSeq,
      prevOfFirst: prev,
      recordCount: recordCount,
      photoFile: photoFile as String?,
    );
  }
}

/// A generated bundle plus the selected records used by the PDF certificate.
final class PassportExport {
  const PassportExport({
    required this.bytes,
    required this.manifest,
    required this.records,
    this.photoBytes,
  });

  final Uint8List bytes;
  final PassportManifest manifest;
  final List<SensorRecord> records;
  final Uint8List? photoBytes;
}

/// Result of checking the sensor's signatures and hash chain in a bundle.
final class PassportVerification {
  const PassportVerification({
    required this.manifest,
    required this.records,
    required this.gaps,
    required this.chain,
    this.photoBytes,
  });

  final PassportManifest manifest;
  final List<SensorRecord> records;
  final List<ReadingGap> gaps;
  final ChainResult chain;
  final Uint8List? photoBytes;

  bool get isValid => chain.isValid;
  bool get hasGaps => gaps.isNotEmpty;
}

/// Builds a 7-day or custom-range passport bundle from received records.
PassportExport createPassportExport({
  required Instrument instrument,
  required List<SensorRecord> history,
  required DateTime from,
  required DateTime to,
  Uint8List? photoBytes,
}) {
  final fromUtc = from.toUtc();
  final toUtc = to.toUtc();
  if (!fromUtc.isBefore(toUtc)) {
    throw ArgumentError('The passport start must be before its end');
  }
  if (photoBytes != null && photoBytes.lengthInBytes > _maxPhotoBytes) {
    throw ArgumentError('Passport photos must be 8 MB or smaller');
  }

  final selected = history
      .where(
        (record) =>
            !record.time.isBefore(fromUtc) && !record.time.isAfter(toUtc),
      )
      .toList(growable: false);
  if (selected.isEmpty) {
    throw StateError('There are no signed records in this date range');
  }
  final firstIndex = history.indexWhere(
    (record) => record.seq == selected.first.seq,
  );
  if (firstIndex < 0) throw StateError('The selected history is inconsistent');
  final previousHash = firstIndex == 0
      ? Uint8List(32)
      : recordHash(history[firstIndex - 1].json);
  final photoFile = photoBytes == null
      ? null
      : 'instrument-photo.${_photoExtension(photoBytes)}';
  final manifest = PassportManifest(
    deviceId: instrument.sensorId,
    publicKey: instrument.sensorPublicKey,
    instrument: instrument,
    from: fromUtc,
    to: toUtc,
    firstSeq: selected.first.seq,
    lastSeq: selected.last.seq,
    prevOfFirst: previousHash,
    recordCount: selected.length,
    photoFile: photoFile,
  );

  final archive = Archive()
    ..add(ArchiveFile.string('manifest.json', jsonEncode(manifest.toJson())))
    ..add(
      ArchiveFile.string(
        'records.jsonl',
        '${selected.map((record) => record.raw).join('\n')}\n',
      ),
    );
  if (photoBytes != null && photoFile != null) {
    archive.add(ArchiveFile.bytes(photoFile, photoBytes));
  }
  return PassportExport(
    bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
    manifest: manifest,
    records: selected,
    photoBytes: photoBytes,
  );
}

/// Parses an `.aelos` ZIP and verifies every record against its sensor key.
Future<PassportVerification> verifyPassportBundle(
  List<int> bundleBytes, {
  int isolates = 4,
}) async {
  if (bundleBytes.isEmpty || bundleBytes.length > _maxBundleBytes) {
    throw const FormatException('Bundle must be smaller than 50 MB');
  }
  final archive = ZipDecoder().decodeBytes(bundleBytes, verify: true);
  final manifestFile = archive.find('manifest.json');
  final recordsFile = archive.find('records.jsonl');
  if (manifestFile == null || recordsFile == null) {
    throw const FormatException('Bundle needs manifest.json and records.jsonl');
  }
  if (recordsFile.size > _maxRecordsBytes) {
    throw const FormatException('Signed history is too large to verify');
  }

  final manifestJson = jsonDecode(utf8.decode(manifestFile.content));
  if (manifestJson is! Map<String, Object?>) {
    throw const FormatException('Passport manifest is not a JSON object');
  }
  final manifest = PassportManifest.fromJson(manifestJson);
  final records = LineSplitter.split(utf8.decode(recordsFile.content))
      .where((line) => line.trim().isNotEmpty)
      .map(SensorRecord.parse)
      .toList(growable: false);
  if (records.isEmpty ||
      records.length != manifest.recordCount ||
      records.first.seq != manifest.firstSeq ||
      records.last.seq != manifest.lastSeq) {
    throw const FormatException(
      'Passport sequence metadata does not match its records',
    );
  }

  Uint8List? photoBytes;
  if (manifest.photoFile != null) {
    final photo = archive.find(manifest.photoFile!);
    if (photo == null || photo.size > _maxPhotoBytes) {
      throw const FormatException('Passport photo is missing or too large');
    }
    photoBytes = photo.content;
  }

  final publicKey = _decodeBase64(manifest.publicKey, 'public key');
  if (publicKey.length != 32) {
    throw const FormatException('Sensor public key must be 32 bytes');
  }
  final chain = await verifyChain(
    [for (final record in records) record.json],
    publicKey: publicKey,
    prevOfFirst: manifest.prevOfFirst,
    isolates: isolates,
  );
  return PassportVerification(
    manifest: manifest,
    records: records,
    gaps: findReadingGaps(records),
    chain: chain,
    photoBytes: photoBytes,
  );
}

Uint8List _decodeBase64(String value, String label) {
  try {
    return Uint8List.fromList(base64Decode(value));
  } on FormatException {
    throw FormatException('Passport $label is not valid base64');
  }
}

String _photoExtension(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'jpg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  if (bytes.length >= 6 &&
      (String.fromCharCodes(bytes.sublist(0, 6)) == 'GIF87a' ||
          String.fromCharCodes(bytes.sublist(0, 6)) == 'GIF89a')) {
    return 'gif';
  }
  return 'bin';
}
