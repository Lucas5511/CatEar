import 'package:flutter/widgets.dart';

/// Design tokens for CatEar.
///
/// Source of truth for the palette is
/// `_bmad-output/planning-artifacts/ux-designs/ux-CatEar-2026-08-26/DESIGN.md`.
/// Several light-mode hex values were darkened (hue preserved) to pass WCAG AA —
/// see the "contrast adjustments" note below and `test/contrast_test.dart`.
///
/// Contrast adjustments (Story 1.1, verified by `test/contrast_test.dart`):
///   ink-secondary       #8A7A6B -> #7E6F62  (text, needs >= 4.5:1)
///   effort-track        #E8A33D -> #C67F17  (graphic, needs >= 3.0:1)
///   skill-track         #7FB396 -> #5C9C78  (graphic, needs >= 3.0:1)
///   scaffold-consonant  #7FB396 -> #5C9C78  (graphic, needs >= 3.0:1)
///   scaffold-dissonant  #E07856 -> #DE6F4B  (graphic, needs >= 3.0:1)
///   border-hairline     #F0E3D2 -> #BA843E  (UI boundary, needs >= 3.0:1)
///   border-hairline-dark #463A2E -> #826C55 (lightened, hue preserved)
/// All other dark-mode values passed unmodified.
abstract final class CatColors {
  // ---- Light ----
  static const surfaceBase = Color(0xFFFFF7EE);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const inkPrimary = Color(0xFF3A2E22);
  static const inkSecondary = Color(0xFF7E6F62);
  static const inkDisabled = Color(0xFFC9BDAF);
  static const accent = Color(0xFFFFC067);
  static const accentSoft = Color(0xFFFBD9B8);
  static const effortTrack = Color(0xFFC67F17);
  static const skillTrack = Color(0xFF5C9C78);
  static const scaffoldConsonant = Color(0xFF5C9C78);
  static const scaffoldDissonant = Color(0xFFDE6F4B);
  static const borderHairline = Color(0xFFBA843E);

  // ---- Dark ----
  static const surfaceBaseDark = Color(0xFF2B241D);
  static const surfaceRaisedDark = Color(0xFF352C23);
  static const inkPrimaryDark = Color(0xFFF5EBDD);
  static const inkSecondaryDark = Color(0xFFC4B3A0);
  static const inkDisabledDark = Color(0xFF6E6255);
  static const accentDark = Color(0xFFFFC067);
  static const accentSoftDark = Color(0xFF5A4633);
  static const effortTrackDark = Color(0xFFF2B85C);
  static const skillTrackDark = Color(0xFF9BCBAE);
  static const scaffoldConsonantDark = Color(0xFF9BCBAE);
  static const scaffoldDissonantDark = Color(0xFFEB9878);
  static const borderHairlineDark = Color(0xFF826C55);
}

/// Corner radii — `sm` for inputs/badges, `md` for cards & primary buttons,
/// `lg` reserved for the mascot bubble and end-of-session win card.
abstract final class CatRadii {
  static const double sm = 10;
  static const double md = 18;
  static const double lg = 28;
}

/// Spacing scale: 4 / 8 / 12 / 16 / 24 / 32.
abstract final class CatSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 24;
  static const double x6 = 32;
}
