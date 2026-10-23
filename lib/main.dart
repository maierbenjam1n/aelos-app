import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/aelos_theme.dart';
import 'core/theme/theme_mode.dart';
import 'features/style_guide/style_guide_screen.dart';

void main() {
  runApp(const ProviderScope(child: AelosApp()));
}

class AelosApp extends ConsumerWidget {
  const AelosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Aelos',
      debugShowCheckedModeBanner: false,
      theme: AelosTheme.light,
      darkTheme: AelosTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      // The style guide stands in until the dashboard exists.
      home: const StyleGuideScreen(),
    );
  }
}
