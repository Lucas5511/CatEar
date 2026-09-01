import 'dart:math' as math;
import 'dart:ui';

/// WCAG 2.x relative-luminance contrast utilities.
///
/// Used by [appTheme] validation, `test/contrast_test.dart`, and the
/// contrast-audit generator. Colours are treated as fully opaque sRGB;
/// any alpha channel is ignored.

double _linearize(double channel) {
  return channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

int _channel8(double normalized) => (normalized * 255.0).round().clamp(0, 255);

/// Relative luminance per WCAG 2.x:
/// `L = 0.2126 R + 0.7152 G + 0.0722 B`, each channel linearised from sRGB.
double relativeLuminance(Color color) {
  final r = _linearize(_channel8(color.r) / 255.0);
  final g = _linearize(_channel8(color.g) / 255.0);
  final b = _linearize(_channel8(color.b) / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Contrast ratio between two colours: `(Lmax + 0.05) / (Lmin + 0.05)`.
/// Ranges from 1.0 (identical) to 21.0 (black on white).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lmax = math.max(la, lb);
  final lmin = math.min(la, lb);
  return (lmax + 0.05) / (lmin + 0.05);
}
