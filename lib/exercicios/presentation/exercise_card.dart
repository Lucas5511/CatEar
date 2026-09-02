/// The reusable Exercise card (UX-DR6): one exercise per screen, `surface-raised`
/// on `rounded/md`, generous breathing room, player + answer centred.
///
/// Story 1.5 reuses this for chord / scale exercises with no branching by type —
/// the card is a plain container, the difference comes from the catalog data.
library;

import 'package:catear/core/core.dart';
import 'package:flutter/material.dart';

/// A single raised card holding the phrase player and the answer area.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final raised = isDark
        ? CatColors.surfaceRaisedDark
        : CatColors.surfaceRaised;
    final border = isDark
        ? CatColors.borderHairlineDark
        : CatColors.borderHairline;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CatSpacing.x5),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CatSpacing.x5,
            vertical: CatSpacing.x6,
          ),
          decoration: BoxDecoration(
            color: raised,
            borderRadius: BorderRadius.circular(CatRadii.md),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [child],
          ),
        ),
      ),
    );
  }
}
