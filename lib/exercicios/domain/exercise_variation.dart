/// Anti-decoreba variation (Story 1.8): the same musical relation, played from
/// a different root.
///
/// The whole mechanism is transposition. An interval and a scale are assembled
/// at runtime out of isolated note samples, so moving one to another root costs
/// nothing but a different set of `audioSampleRef`s — no new audio file, and no
/// change to the catalog↔assets parity gate, because every token it can produce
/// is already referenced by the catalog.
///
/// Two properties this file exists to keep true:
///
///  * **The musical parameters come from the catalog.** The offsets are read
///    off `IntervalSpec.semitones` and `ScaleSpec.steps`; nothing here knows an
///    interval or a mode by name. Adding a mode to the catalog gives it
///    variation for free.
///  * **A variation is only offered if all of its notes exist.** The sample
///    inventory is irregular (C4-C5 chromatic plus D5, no Db5), so a root is
///    *found*, never assumed. `assets/audio/` can therefore never be asked for
///    a file it does not have.
///
/// A chord is deliberately outside all of this (human decision, 2026-09-09):
/// its root is baked into the pre-rendered triad block, and transposing it
/// would mean either runtime synthesis or multi-voice playback — both `Never`s
/// since Story 1.4b. [variantsFor] returns an empty pool for it, `questionFor`
/// then plays the catalog refs verbatim, and that is defined behaviour rather
/// than a gap.
library;

import 'package:catear/audio/audio.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:flutter/foundation.dart';

import 'exercise_question.dart';

/// How many exercises back the "do not repeat" window reaches.
///
/// One full sequence (the 39-question loop of Story 1.7), and counted **in
/// exercises, not in sessions**: practising twice in a day must not be the
/// thing that brings a variation back early.
const int variantWindow = 39;

/// One variation: a musical relation, and the root it is played from.
///
/// [relationKey] is the identity the window is kept per — it says *what* is
/// being asked (`interval:M3:asc`), never *where from*. Direction is part of
/// it because ascending and descending are different exercises with different
/// audio, and each deserves its own rotation through the roots.
@immutable
class ExerciseVariant {
  const ExerciseVariant({required this.relationKey, required this.rootToken});

  final String relationKey;

  /// The isolated-note token the relation is built up from.
  final String rootToken;

  @override
  bool operator ==(Object other) =>
      other is ExerciseVariant &&
      other.relationKey == relationKey &&
      other.rootToken == rootToken;

  @override
  int get hashCode => Object.hash(relationKey, rootToken);

  @override
  String toString() => 'ExerciseVariant($relationKey @ $rootToken)';
}

/// The stable identity of the relation [exercise] asks about, or `null` when
/// the exercise does not vary.
///
/// Written into the database, so it must not drift with a refactor: it is built
/// out of catalog ids and enum *names*, never an index or a `hashCode`.
String? relationKeyFor(Exercise exercise) => switch (exercise) {
  IntervalExercise() =>
    'interval:${exercise.interval.id}:${exercise.direction.name}',
  ScaleExercise() => 'scale:${exercise.scale.id}:${exercise.direction.name}',
  // A chord's root is inside the file; a cadence is sung and inert until
  // Epic 3. Neither has a root to choose.
  ChordExercise() => null,
  ResolutionExercise() => null,
};

/// The semitone offsets above the root, **in playing order**, that [exercise]
/// is made of — or `null` when it cannot be transposed.
///
/// This is the single place the catalog's musical data is turned into "which
/// notes, in which order":
///
///  * interval — `[0, semitones]` ascending, reversed descending, exactly the
///    `[lower, upper]` / `[upper, lower]` contract of `Exercise.audioSampleRefs`
///  * scale — the tonic plus the running sum of `steps` (8 degrees for the
///    v1 modes), reversed descending
List<int>? variantOffsets(Exercise exercise) => switch (exercise) {
  IntervalExercise() =>
    exercise.direction == Direction.asc
        ? [0, exercise.interval.semitones]
        : [exercise.interval.semitones, 0],
  ScaleExercise() => () {
    final degrees = [0, ...degreesFromSteps(exercise.scale.steps)];
    return exercise.direction == Direction.asc
        ? degrees
        : degrees.reversed.toList();
  }(),
  ChordExercise() => null,
  ResolutionExercise() => null,
};

/// Every root [exercise] can be played from, **ordered from the lowest pitch
/// up**, empty when the exercise does not vary.
///
/// A root qualifies only when the sample set has *every* note the relation
/// needs from it — which is why the pool shrinks as the interval grows (the top
/// of the inventory runs out) and why the major scale has exactly one root
/// (D major would need Db5, which does not exist). The uneven ceiling is
/// accepted as given (human decision, 2026-09-09): no exercise gets worse than
/// it is today and most get much better.
///
/// The order is by pitch so the choice is reproducible: with an empty history
/// the loop picks the lowest root, which is the root the catalog already
/// writes, so a fresh install hears exactly what it heard before this story.
List<ExerciseVariant> variantsFor(Exercise exercise) {
  final relationKey = relationKeyFor(exercise);
  final offsets = variantOffsets(exercise);
  if (relationKey == null || offsets == null) return const [];

  final variants = <ExerciseVariant>[];
  for (final root in noteTokensByPitch) {
    if (offsets.every((o) => transposedNoteToken(root, o) != null)) {
      variants.add(ExerciseVariant(relationKey: relationKey, rootToken: root));
    }
  }
  return List.unmodifiable(variants);
}

/// The `audioSampleRef`s of [exercise] played from [variant]'s root.
///
/// Throws [StateError] when the root does not resolve — it cannot, for a
/// variant that came from [variantsFor], and a silently dropped note would be
/// a wrong exercise rather than a loud failure.
List<String> refsForVariant(Exercise exercise, ExerciseVariant variant) {
  final offsets = variantOffsets(exercise);
  if (offsets == null) return exercise.audioSampleRefs;
  return [
    for (final offset in offsets)
      transposedNoteToken(variant.rootToken, offset) ??
          (throw StateError(
            'no sample $offset semitones above ${variant.rootToken} — '
            '${variant.relationKey} should not have offered this root',
          )),
  ];
}

/// Picks the variation to play, given [pool], the recent history [window]
/// (**newest first**, already limited to [variantWindow] entries) and
/// [lastUseByRoot] — the sequence of each root's most recent use *ever*, for
/// this relation, from the whole retained history.
///
/// The rule, in order:
///
///  1. among the roots the window leaves free, the one used **least recently
///     in all of history** — a root never heard before comes first, and ties
///     break towards the lower pitch so the choice stays deterministic;
///  2. otherwise, the pool is exhausted inside the window: the least recently
///     used root of the pool. Controlled repetition, never a lock-up, and
///     never the root that just played as long as the pool holds more than
///     one.
///
/// Step 1 reads all of history and not just [window], and that is the whole
/// difference between rotating and alternating (human decision, 2026-09-09).
/// The window is only ~1.26 sessions wide — 39 records against the 31 varying
/// exercises of a loop — so a relation has at most one use inside it. Picking
/// "the lowest root the window left free" therefore returns the second-lowest
/// root every time, and the session after that returns the lowest again: two
/// roots, forever, whether the pool holds 2 or 14. Ordering the free roots by
/// how long ago they actually played is what walks the pool.
///
/// A pool of one repeats, by construction. That is the measured ceiling of the
/// sample set, not a failure.
///
/// Throws [ArgumentError] on an empty [pool]: an invariant exercise has no
/// variation to choose, and its caller must not ask.
ExerciseVariant chooseVariant(
  List<ExerciseVariant> pool,
  List<VariantUse> window, {
  Map<String, int> lastUseByRoot = const {},
}) {
  if (pool.isEmpty) {
    throw ArgumentError.value(pool, 'pool', 'no variation to choose from');
  }

  // Most recent use per root *inside the window*, for this relation only.
  // `window` is newest first, so the first sighting of a root is its latest.
  final inWindow = <String, int>{};
  for (final use in window) {
    if (use.relationKey != pool.first.relationKey) continue;
    inWindow.putIfAbsent(use.rootToken, () => use.sequence);
  }

  final free = [
    for (final variant in pool)
      if (!inWindow.containsKey(variant.rootToken)) variant,
  ];
  if (free.isNotEmpty) {
    // `pool` is ordered by pitch and the fold keeps the first of any tie, so
    // never-heard roots (absent from `lastUseByRoot`, hence -1) are taken
    // lowest-first before any root is repeated.
    var best = free.first;
    var bestSequence = lastUseByRoot[best.rootToken] ?? -1;
    for (final variant in free.skip(1)) {
      final sequence = lastUseByRoot[variant.rootToken] ?? -1;
      if (sequence < bestSequence) {
        best = variant;
        bestSequence = sequence;
      }
    }
    return best;
  }

  var lru = pool.first;
  var lruSequence = inWindow[lru.rootToken]!;
  for (final variant in pool.skip(1)) {
    final sequence = inWindow[variant.rootToken]!;
    if (sequence < lruSequence) {
      lru = variant;
      lruSequence = sequence;
    }
  }
  return lru;
}
