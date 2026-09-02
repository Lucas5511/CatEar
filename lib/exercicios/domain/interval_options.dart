/// Pure generation of the 4 multiple-choice options for an interval exercise.
library;

import 'dart:math';

import 'package:catear/curriculo/curriculo.dart';

/// Returns exactly 4 [IntervalSpec] options — the [answer] plus 3 distractors —
/// unless [pool] cannot supply that many, in which case it returns as many
/// distinct specs as it can and **always** includes [answer].
///
/// Distractors are the 3 closest available specs by semitone distance — the
/// confusions real ear training produces. Candidates are ranked by
/// `|semitones - answer.semitones|` (ties broken by `id`) and the nearest are
/// taken; near the ends of the range (P1 / P8) the 3rd distractor can sit 3
/// semitones away. The final order is a deterministic Fisher-Yates shuffle
/// keyed on [seed], so options are stable across widget rebuilds and
/// reproducible in tests.
List<IntervalSpec> intervalOptionsFor(
  IntervalSpec answer,
  Iterable<IntervalSpec> pool, {
  required int seed,
}) {
  final candidates = <IntervalSpec>[];
  final seenIds = <String>{answer.id};
  for (final spec in pool) {
    if (seenIds.add(spec.id)) candidates.add(spec);
  }

  candidates.sort((a, b) {
    final da = (a.semitones - answer.semitones).abs();
    final db = (b.semitones - answer.semitones).abs();
    if (da != db) return da.compareTo(db);
    return a.id.compareTo(b.id);
  });

  final options = <IntervalSpec>[answer, ...candidates.take(3)];

  final rng = Random(seed);
  for (var i = options.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = options[i];
    options[i] = options[j];
    options[j] = tmp;
  }
  return options;
}
