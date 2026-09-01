import 'package:catear/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final light = appTheme(Brightness.light);
  final dark = appTheme(Brightness.dark);

  test('light and dark differ on key colours', () {
    expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
    expect(light.colorScheme.onSurface, isNot(dark.colorScheme.onSurface));
    expect(light.scaffoldBackgroundColor, isNot(dark.scaffoldBackgroundColor));
  });

  test('light is the warm cream default', () {
    expect(light.colorScheme.surface, CatColors.surfaceBase);
    expect(light.brightness, Brightness.light);
  });

  test('body text does not use Fredoka', () {
    expect(light.textTheme.bodyMedium?.fontFamily, isNot('Fredoka'));
    expect(dark.textTheme.bodyLarge?.fontFamily, isNot('Fredoka'));
    expect(light.textTheme.titleLarge?.fontFamily, isNot('Fredoka'));
  });

  test('CatText.display is Fredoka with a sans-serif fallback', () {
    expect(CatText.display.fontFamily, 'Fredoka');
    expect(CatText.display.fontFamilyFallback, contains('sans-serif'));
    expect(CatText.display.fontWeight, FontWeight.w500);
  });

  test('radii and spacing tokens', () {
    expect(CatRadii.sm, 10);
    expect(CatRadii.md, 18);
    expect(CatRadii.lg, 28);
    expect(CatSpacing.x1, 4);
    expect(CatSpacing.x6, 32);
  });
}
