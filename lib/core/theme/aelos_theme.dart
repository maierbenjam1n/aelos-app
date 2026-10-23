import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'aelos_colors.dart';
import 'aelos_type.dart';
import 'tokens.dart';

abstract final class AelosTheme {
  static final light = _build(Brightness.light, AelosColors.light);
  static final dark = _build(Brightness.dark, AelosColors.dark);

  static ThemeData _build(Brightness brightness, AelosColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: AelosPalette.ivory,
      secondary: c.calm,
      onSecondary: c.background,
      error: c.actNow,
      onError: AelosPalette.ivory,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      outline: c.hairline,
      outlineVariant: c.hairline,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
    );
    final textTheme = aelosTextTheme(c.text, c.textMuted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: textTheme,
      fontFamily: Fonts.sans,
      extensions: [c, AelosText.forColors(c.text, c.textMuted)],
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 0.8, space: 0.8),
      iconTheme: IconThemeData(color: c.textMuted, size: 22),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: AelosPalette.ivory,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 52),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radii.m)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.hairline),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 52),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radii.m)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentInk,
          textStyle: textTheme.labelLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceRaised,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radii.m)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
