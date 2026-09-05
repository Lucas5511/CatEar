/// Pure functions that turn the curriculum catalog into the fixed practice loop
/// of Story 1.4.
///
/// No session sizing (1.7), no anti-decoreba variation (1.8), no randomness:
/// every selected exercise of the catalog, in `stage.order`, once.
///
/// The *shape* is type-agnostic since Story 1.5a — the loop is a list of
/// [ExerciseQuestion] and the pool a list of [AnswerOption]. The *selection* is
/// still intervals only: [types] defaults to `{ExerciseType.interval}`, and
/// flipping that default is Story 1.5, a visible product change.
library;

import 'package:catear/curriculo/curriculo.dart';

import 'exercise_question.dart';

/// The exercise types the practice loop draws from until Story 1.5 turns chord
/// and scale on. Named so the intent is greppable rather than a bare literal.
const Set<ExerciseType> defaultPracticeTypes = {ExerciseType.interval};

/// The fixed loop: every exercise of [types] flattened in ascending
/// `stage.order` (the JSON array order is not canonical), projected onto the
/// type-agnostic [ExerciseQuestion].
List<ExerciseQuestion> practiceLoop(
  Curriculum curriculum, {
  Set<ExerciseType> types = defaultPracticeTypes,
}) {
  final stages = [...curriculum.stages]
    ..sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.stageId.compareTo(b.stageId);
    });
  return [
    for (final stage in stages)
      for (final exercise in stage.exercises)
        // `requiresVoice` is the second half of the filter, not a redundancy:
        // a sung exercise (resolution, Epic 3) has no tap-to-answer surface, so
        // it stays out even if a caller names its type.
        if (types.contains(exercise.type) && !exercise.requiresVoice)
          questionFor(exercise),
  ];
}

/// The distinct [AnswerOption]s that appear in the practice loop, in first-seen
/// order. This is the distractor pool for `answerOptionsFor` (13 in v1).
///
/// Dedupe is keyed on `(type, id)`, never on the bare id: `chordCatalog` and
/// `scaleCatalog` both carry an `id: "major"`, so a bare-id pool would collapse
/// the major triad and the major scale into one option — and `_OptionButton`
/// compares `option.id == answer.id`, which would then mark a scale button
/// correct for a chord answer. Inert while the loop is single-type, and exactly
/// the trap Story 1.5's mixed loop of 39 would spring.
List<AnswerOption> practicePool(
  Curriculum curriculum, {
  Set<ExerciseType> types = defaultPracticeTypes,
}) {
  final seen = <(ExerciseType, String)>{};
  final pool = <AnswerOption>[];
  for (final question in practiceLoop(curriculum, types: types)) {
    if (seen.add((question.type, question.answer.id))) {
      pool.add(question.answer);
    }
  }
  return pool;
}
