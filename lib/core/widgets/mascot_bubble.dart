/// The mascot's speech bubble (UX-DR4): `rounded/lg`, `accent-soft`, a warm
/// shadow floating it above the card, and the app's only Fredoka style.
///
/// Public since Story 1.9 — moved verbatim out of
/// `lib/exercicios/presentation/exercise_card_flow.dart`, where it was private
/// — because the design asks for the bubble in four places (the levelling
/// welcome, error feedback, the celebration, the session summary) and two
/// modules already render it. It lives in `core/` as a shared widget with no
/// module state of its own: it takes a sentence and draws it.
///
/// Inline and additive — never a route, never a `showDialog`. `EXPERIENCE.md`
/// asks for "um bubble curto, sem tela cheia de bloqueio", and the epic's
/// "o modal empilha só um nível" is satisfied by stacking nothing at all.
library;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// One sentence in the mascot's voice.
class MascotBubble extends StatelessWidget {
  const MascotBubble({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? CatColors.accentSoftDark : CatColors.accentSoft;
    // Verified against `accent-soft` in `test/contrast_test.dart` (>= 4.5:1 in
    // both themes). No red anywhere — UX-DR14, and the palette has none.
    final ink = isDark ? CatColors.inkPrimaryDark : CatColors.inkPrimary;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CatSpacing.x5,
          vertical: CatSpacing.x4,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(CatRadii.lg),
          boxShadow: [
            BoxShadow(
              // Warm, never a cold grey (DESIGN.md § Elevation & Depth).
              color: (isDark ? CatColors.surfaceBaseDark : CatColors.inkPrimary)
                  .withValues(alpha: isDark ? 0.55 : 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          // `CatText.display` stays the app's single Fredoka source; only the
          // scale is stepped down, because 28 is a headline size and this is a
          // two-clause sentence inside a card. Family and weight — the mascot's
          // voice — come from the token untouched.
          style: CatText.display.copyWith(
            fontSize: 20,
            height: 1.35,
            color: ink,
          ),
        ),
      ),
    );
  }
}
