/// Pure generation of the 4 multiple-choice options for a practice exercise.
library;

import 'dart:math';

import 'package:catear/curriculo/curriculo.dart';

import 'exercise_question.dart';

/// The 4 options for [question], drawn **only** from its own type's pool.
///
/// This is the entry point the practice loop uses, and it exists so that
/// passing the wrong pool is not something a caller can do by accident:
/// `poolsByType` is the whole map and the type is read off the question. A
/// distractor from another type would be nonsense to the learner — see
/// `practicePool` for why a merged pool ranks a triad above most intervals.
///
/// Throws [ArgumentError] when [poolsByType] has no entry for the question's
/// type. That cannot happen while both sides come from the same
/// `practicePool` call, and falling back to an empty pool would silently ship a
/// card with one button on it — a broken exercise that answers itself.
List<AnswerOption> answerOptionsForQuestion(
  ExerciseQuestion question,
  Map<ExerciseType, List<AnswerOption>> poolsByType, {
  required int seed,
}) {
  final pool = poolsByType[question.type];
  if (pool == null) {
    throw ArgumentError.value(
      poolsByType.keys.toList(),
      'poolsByType',
      'no distractor pool for ${question.type} — the pool and the loop must '
          'come from the same practicePool/practiceLoop pair',
    );
  }
  return answerOptionsFor(question.answer, pool, seed: seed);
}

/// Returns exactly 4 [AnswerOption]s — the [answer] plus 3 distractors —
/// unless [pool] cannot supply that many, in which case it returns as many
/// distinct options as it can and **always** includes [answer].
///
/// Distractors are the 3 closest available options by
/// [AnswerOption.distanceTo] — the confusions real ear training produces.
/// Candidates are ranked by that distance (ties broken by `id`) and the nearest
/// are taken; near the ends of an interval range (P1 / P8) the 3rd distractor
/// can sit 3 semitones away. Because an interval's profile is a single
/// semitone count, the ranking is identical to Story 1.4's
/// `|semitones - answer.semitones|`.
///
/// The final order is a deterministic Fisher-Yates shuffle keyed on [seed], so
/// options are stable across widget rebuilds and reproducible in tests.
///
/// [pool] must hold options of the answer's own type only; prefer
/// [answerOptionsForQuestion], which enforces that.
List<AnswerOption> answerOptionsFor(
  AnswerOption answer,
  Iterable<AnswerOption> pool, {
  required int seed,
}) {
  final candidates = <AnswerOption>[];
  final seenIds = <String>{answer.id};
  for (final option in pool) {
    if (seenIds.add(option.id)) candidates.add(option);
  }

  candidates.sort((a, b) {
    final da = answer.distanceTo(a);
    final db = answer.distanceTo(b);
    if (da != db) return da.compareTo(db);
    return a.id.compareTo(b.id);
  });

  final options = <AnswerOption>[answer, ...candidates.take(3)];

  final rng = Random(seed);
  for (var i = options.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = options[i];
    options[i] = options[j];
    options[j] = tmp;
  }
  return options;
}
