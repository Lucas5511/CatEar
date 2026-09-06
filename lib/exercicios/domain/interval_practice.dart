/// Pure functions that turn the curriculum catalog into the fixed practice loop
/// of Story 1.4.
///
/// No session sizing (1.7), no anti-decoreba variation (1.8), no randomness:
/// every selected exercise of the catalog, in `stage.order`, once.
///
/// The *shape* is type-agnostic since Story 1.5a. Story 1.5 flipped the
/// selection: [defaultPracticeTypes] is now every tappable type, so the v1 loop
/// is 39 questions (23 intervals + 8 chords + 8 scales), and the distractor
/// pool is **keyed by type** — the options offered for a chord may never be
/// drawn from the interval catalog.
library;

import 'package:catear/curriculo/curriculo.dart';

import 'exercise_question.dart';

/// The exercise types the practice loop draws from: every type that is answered
/// by tapping.
///
/// `resolution` is absent because it is sung (Epic 3) — but the loop does not
/// rely on that absence: [practiceLoop] filters on `requiresVoice` as well, so
/// naming a sung type here still cannot put it on a multiple-choice card.
const Set<ExerciseType> defaultPracticeTypes = {
  ExerciseType.interval,
  ExerciseType.chord,
  ExerciseType.scale,
};

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

/// The distractor pool, **one list per [ExerciseType]**, each in first-seen
/// order. In v1: 13 intervals, 4 chord qualities, 4 scale modes.
///
/// Split by type, not merged, because `AnswerOption.distanceTo` compares
/// semitone profiles with no notion of type: a major triad (`[4, 7]`) sits 3
/// away from a major third (`[4]`), closer than most intervals. A single pool
/// would therefore offer "tríade maior" as an alternative to an interval
/// question — the exercise would stop making sense and the skill signal Epic 2
/// is built on would be contaminated from birth.
///
/// Within a type, dedupe is keyed on the id; across types it cannot collide by
/// construction. That matters because `chordCatalog` and `scaleCatalog` both
/// carry an `id: "major"` and the option button compares
/// `option.id == answer.id`.
Map<ExerciseType, List<AnswerOption>> practicePool(
  Curriculum curriculum, {
  Set<ExerciseType> types = defaultPracticeTypes,
}) {
  final seen = <(ExerciseType, String)>{};
  final pools = <ExerciseType, List<AnswerOption>>{};
  for (final question in practiceLoop(curriculum, types: types)) {
    if (seen.add((question.type, question.answer.id))) {
      (pools[question.type] ??= <AnswerOption>[]).add(question.answer);
    }
  }
  return {
    for (final entry in pools.entries)
      entry.key: List.unmodifiable(entry.value),
  };
}
