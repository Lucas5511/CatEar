import 'package:flutter/material.dart';

import 'tokens.dart';

/// Typography for CatEar.
///
/// Body, titles and numbers use the platform system font (never Fredoka).
/// **Fredoka** (static instances) is only reachable through [CatText.display]
/// and is reserved for mascot speech and win / milestone screens.
abstract final class CatText {
  /// System-font text theme, tinted with the ink tokens for [brightness].
  static TextTheme textTheme(Brightness brightness) {
    final ink = brightness == Brightness.dark
        ? CatColors.inkPrimaryDark
        : CatColors.inkPrimary;
    final inkSecondary = brightness == Brightness.dark
        ? CatColors.inkSecondaryDark
        : CatColors.inkSecondary;
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;
    return base
        .apply(bodyColor: ink, displayColor: ink, fontFamily: null)
        .copyWith(
          bodySmall: base.bodySmall?.copyWith(color: inkSecondary),
          labelSmall: base.labelSmall?.copyWith(color: inkSecondary),
        );
  }

  /// The only Fredoka style in the app. Weight 500 (Medium).
  /// Falls back to the platform sans-serif if the asset is unavailable.
  static const TextStyle display = TextStyle(
    fontFamily: 'Fredoka',
    fontFamilyFallback: ['sans-serif'],
    fontWeight: FontWeight.w500,
    fontSize: 28,
    height: 1.2,
  );
}
