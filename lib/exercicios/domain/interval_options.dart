/// Pure generation of the 4 multiple-choice options for a practice exercise.
library;

import 'dart:math';

import 'exercise_question.dart';

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
