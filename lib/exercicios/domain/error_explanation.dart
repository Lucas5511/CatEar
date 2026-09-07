/// The mascot's line for a wrong answer (Story 1.6).
///
/// FR-4: an error names the confused concept, never just "errado". The text is
/// built **here**, in `domain/`, and reaches the widget as a finished string —
/// the same reason `ExerciseQuestion` exists (Rule 6 of
/// `tool/check_module_boundaries.dart`): if choosing the phrase lived in the
/// widget, `lib/exercicios/presentation/` would branch per exercise type again,
/// which is exactly the debt Story 1.5a spent a whole story removing.
///
/// Two layers, by human decision (2026-09-07):
///
///  * **Base** — names the pair with the `nameUi`s the screen already shows.
///    Covers every case with nothing to maintain per exercise type.
///  * **Specific** — used only where the [ErrorType] says something the two
///    option labels do not: which scale degree moved
///    ([ErrorType.tercaAlterada] / [ErrorType.sextaAlterada] /
///    [ErrorType.setimaAlterada]) and the far miss ([ErrorType.farMiss]).
///    Story 1.4b named the scale errors by *degree* rather than by mode
///    precisely so this layer could exist.
///
/// [ErrorType.octaveError] gets no phrase of its own, deliberately: nothing
/// produces it. `ExerciseAttempt.errorTypeFor` resolves an interval pick by
/// catalog id, and the id of an octave is `P8` ([ErrorType.p8], the interval);
/// no catalog id is `octave-error`, and chord / scale / resolution cannot reach
/// it either. Real octave-slip detection (same pitch class, different register)
/// needs `errorTypeFor` to change, which this story's Never forbids — see
/// `_bmad-output/implementation-artifacts/deferred-work.md`.
///
/// [ErrorType.farMiss] is a first-class case, not an embarrassed fallback:
/// since Story 1.5a a wrong answer's `errorType` is **never** null — anything
/// unmapped resolves to `far-miss` on purpose, because a null or a throw in the
/// middle of a session used to take the screen down. "Far miss" means *the two
/// sit too far apart to name a single confusion*, which is itself teaching, so
/// its line still names the right answer and invites another listen.
library;

import 'package:catear/curriculo/curriculo.dart';

import 'exercise_question.dart';

/// The scale [ErrorType]s that name a single altered degree, and how the
/// mascot says that degree out loud.
///
/// The exact inverse of `scaleErrorTypeByDegree` in `exercise_attempt.dart`:
/// that map resolves a degree to a taxonomy value, this one turns the taxonomy
/// value back into words. Keeping them apart keeps this story read-only over
/// the taxonomy Story 1.5a produced; `error_explanation_test.dart` asserts the
/// two key sets match, so a degree *added* to the taxonomy cannot silently fall
/// through to the base template here.
const Map<ErrorType, String> alteredDegreeNames = {
  ErrorType.tercaAlterada: '3ª',
  ErrorType.sextaAlterada: '6ª',
  ErrorType.setimaAlterada: '7ª',
};

/// The mascot's explanation for a wrong answer, ready to draw.
///
/// [answer] is what the exercise actually was; [picked] is what the learner
/// tapped; [errorType] is the taxonomy value recorded on the attempt.
///
/// Total by construction — it is called mid-session, from a widget `build`, so
/// it never throws and never returns an empty string. [picked] and [errorType]
/// are nullable only to absorb a state that should not reach here (a result
/// rendered before an answer exists); that path still names the right answer.
String errorExplanation({
  required AnswerOption answer,
  AnswerOption? picked,
  ErrorType? errorType,
}) {
  if (picked == null || errorType == null) {
    return 'Não foi dessa vez. Era ${answer.nameUi} — ouça de novo com calma.';
  }

  final degree = alteredDegreeNames[errorType];
  if (degree != null) {
    // The whole point of naming scale errors by degree: "escala maior vs.
    // escala mixolídia" tells the learner nothing they cannot read off the
    // buttons; "a diferença está só na 7ª" tells them where to listen.
    return 'Quase lá — era ${answer.nameUi}. A diferença para '
        '${picked.nameUi} está só na $degree: ouça de novo prestando '
        'atenção nela.';
  }

  return switch (errorType) {
    ErrorType.farMiss =>
      'Era ${answer.nameUi} — bem longe de ${picked.nameUi}. Ouça de novo '
          'com calma e compare as duas.',
    // Base layer: every interval and chord confusion, named by the labels the
    // learner just read. UX-DR14's own example sentence.
    _ => 'Quase lá — você confundiu ${answer.nameUi} com ${picked.nameUi}.',
  };
}
