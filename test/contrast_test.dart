import 'package:catear/core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrast is verified here, computed from the token hex values — not by a
/// hand-maintained document. Text pairs need >= 4.5:1; graphic / UI-boundary
/// pairs (effort-track, skill-track, scaffold-*, border-hairline) need >= 3.0:1.
void main() {
  const textThreshold = 4.5;
  const graphicThreshold = 3.0;

  group('light mode', () {
    const backgrounds = {
      'surface-base': CatColors.surfaceBase,
      'surface-raised': CatColors.surfaceRaised,
    };
    const text = {
      'ink-primary': CatColors.inkPrimary,
      'ink-secondary': CatColors.inkSecondary,
    };
    const graphic = {
      'effort-track': CatColors.effortTrack,
      'skill-track': CatColors.skillTrack,
      'scaffold-consonant': CatColors.scaffoldConsonant,
      'scaffold-dissonant': CatColors.scaffoldDissonant,
      'border-hairline': CatColors.borderHairline,
    };

    backgrounds.forEach((bgName, bg) {
      text.forEach((fgName, fg) {
        test('$fgName on $bgName >= $textThreshold', () {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(textThreshold));
        });
      });
    });

    graphic.forEach((fgName, fg) {
      test('$fgName on surface-base >= $graphicThreshold', () {
        expect(
          contrastRatio(fg, CatColors.surfaceBase),
          greaterThanOrEqualTo(graphicThreshold),
        );
      });
    });

    // Story 1.6's mascot bubble made `accent-soft` a text background. It is
    // audited on its own rather than added to `backgrounds` above because the
    // only ink ever drawn on it is `ink-primary` (`CatText.display`);
    // `ink-secondary` on `accent-soft` is 3.6:1, and failing the build over a
    // pair the app never renders would buy nothing and cost a token change.
    test('ink-primary on accent-soft >= $textThreshold', () {
      expect(
        contrastRatio(CatColors.inkPrimary, CatColors.accentSoft),
        greaterThanOrEqualTo(textThreshold),
      );
    });
  });

  group('dark mode', () {
    const backgrounds = {
      'surface-base-dark': CatColors.surfaceBaseDark,
      'surface-raised-dark': CatColors.surfaceRaisedDark,
    };
    const text = {
      'ink-primary-dark': CatColors.inkPrimaryDark,
      'ink-secondary-dark': CatColors.inkSecondaryDark,
    };
    const graphic = {
      'effort-track-dark': CatColors.effortTrackDark,
      'skill-track-dark': CatColors.skillTrackDark,
      'scaffold-consonant-dark': CatColors.scaffoldConsonantDark,
      'scaffold-dissonant-dark': CatColors.scaffoldDissonantDark,
      'border-hairline-dark': CatColors.borderHairlineDark,
    };

    backgrounds.forEach((bgName, bg) {
      text.forEach((fgName, fg) {
        test('$fgName on $bgName >= $textThreshold', () {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(textThreshold));
        });
      });
    });

    graphic.forEach((fgName, fg) {
      test('$fgName on surface-base-dark >= $graphicThreshold', () {
        expect(
          contrastRatio(fg, CatColors.surfaceBaseDark),
          greaterThanOrEqualTo(graphicThreshold),
        );
      });
    });

    // The mascot bubble in dark mode — same reasoning as the light pair above.
    test('ink-primary-dark on accent-soft-dark >= $textThreshold', () {
      expect(
        contrastRatio(CatColors.inkPrimaryDark, CatColors.accentSoftDark),
        greaterThanOrEqualTo(textThreshold),
      );
    });
  });

  test('known reference: black on white is ~21', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.5),
    );
  });
}
