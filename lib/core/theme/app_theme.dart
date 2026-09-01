import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Builds the CatEar [ThemeData] for the given [brightness] from the design
/// tokens. Light (warm cream pastel) is the default; dark replays the same
/// warmth in deep warm tones.
ThemeData appTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final surfaceBase = isDark
      ? CatColors.surfaceBaseDark
      : CatColors.surfaceBase;
  final surfaceRaised = isDark
      ? CatColors.surfaceRaisedDark
      : CatColors.surfaceRaised;
  final inkPrimary = isDark ? CatColors.inkPrimaryDark : CatColors.inkPrimary;
  final inkSecondary = isDark
      ? CatColors.inkSecondaryDark
      : CatColors.inkSecondary;
  final accent = isDark ? CatColors.accentDark : CatColors.accent;
  final border = isDark
      ? CatColors.borderHairlineDark
      : CatColors.borderHairline;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: CatColors.inkPrimary,
    secondary: isDark ? CatColors.accentSoftDark : CatColors.accentSoft,
    onSecondary: inkPrimary,
    error: isDark
        ? CatColors.scaffoldDissonantDark
        : CatColors.scaffoldDissonant,
    onError: isDark ? CatColors.inkPrimary : CatColors.surfaceRaised,
    surface: surfaceBase,
    onSurface: inkPrimary,
    surfaceContainerHighest: surfaceRaised,
    onSurfaceVariant: inkSecondary,
    outline: border,
    outlineVariant: border,
  );

  final textTheme = CatText.textTheme(brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surfaceBase,
    canvasColor: surfaceBase,
    textTheme: textTheme,
    fontFamily: null,
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceBase,
      foregroundColor: inkPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surfaceRaised,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CatRadii.md),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceRaised,
      indicatorColor: isDark ? CatColors.accentSoftDark : CatColors.accentSoft,
      elevation: 2,
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(color: inkPrimary),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: inkPrimary)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: CatColors.inkPrimary,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CatRadii.md),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, space: CatSpacing.x4),
  );
}
