import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the bundled fonts and Material icons so screenshots render real text.
Future<void> loadAppFonts() async {
  Future<ByteData> file(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  final serif = FontLoader('CormorantGaramond');
  final sans = FontLoader('Inter');
  for (final f in Directory('assets/fonts').listSync().whereType<File>()) {
    if (!f.path.endsWith('.ttf')) continue;
    (f.path.contains('Cormorant') ? serif : sans).addFont(file(f.path));
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(file(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ));
  await Future.wait([serif.load(), sans.load(), icons.load()]);
}
