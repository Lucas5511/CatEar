/// Pure functions that turn the curriculum catalog into the fixed practice loop
/// of Story 1.4.
///
/// Every selected exercise of the catalog, in `stage.order`, once — the
/// sequence itself has not moved since Story 1.4 and is not sorted, sampled or
/// shortened here (that is Story 2.8).
///
/// Story 1.8 changed *what each position plays*, not which positions there are:
/// each one is transposed to a root chosen off the recent-variation history, so
/// two sessions in a row do not sound the same. Choosing is pure — the history
/// is an argument, and the caller is the one that talks to the database.
///
/// The *shape* is type-agnostic since Story 1.5a. Story 1.5 flipped the
/// selection: [defaultPracticeTypes] is now every tappable type, so the v1 loop
/// is 39 questions (23 intervals + 8 chords + 8 scales), and the distractor
/// pool is **keyed by type** — the options offered for a chord may never be
/// drawn from the interval catalog.
library;

import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/progressao/progressao.dart';

import 'exercise_question.dart';
import 'exercise_variation.dart';

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
/// type-agnostic [ExerciseQuestion] and transposed to a root chosen against
/// [history].
///
/// [history] is the recent-variation window, **newest first**, as
/// `VariantHistoryRepository.recent` returns it — the roots that may *not*
/// play. [lastUses] is `VariantHistoryRepository.lastUsePerRoot`: the latest
/// use of every (relation, root) pair in the whole retained history, which is
/// what orders the roots the window left free.
///
/// Both empty — a first run, or a database that could not be read — makes
/// every position pick the lowest root of its pool, which is the root the
/// catalog itself writes: a fresh install hears exactly what it heard before
/// Story 1.8.
///
/// The choices made here feed back into both, so two positions of the same
/// relation inside one loop cannot land on the same root while the pool has
/// another one to offer.
List<ExerciseQuestion> practiceLoop(
  Curriculum curriculum, {
  Set<ExerciseType> types = defaultPracticeTypes,
  List<VariantUse> history = const [],
  List<VariantUse> lastUses = const [],
}) {
  final stages = [...curriculum.stages]
    ..sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.stageId.compareTo(b.stageId);
    });

  // Newest first, capped at the window. Sorted rather than trusted: a caller
  // that hands the rows over in the wrong order would silently turn "least
  // recently used" into "most recently used".
  final window = [...history]..sort((a, b) => b.sequence.compareTo(a.sequence));
  if (window.length > variantWindow) {
    window.removeRange(variantWindow, window.length);
  }
  var nextSequence = window.isEmpty ? 1 : window.first.sequence + 1;

  // relationKey -> rootToken -> sequence of that root's most recent use, over
  // the whole retained history rather than just the window.
  final lastUseByRelation = <String, Map<String, int>>{};
  for (final use in lastUses) {
    final byRoot = lastUseByRelation.putIfAbsent(use.relationKey, () => {});
    final known = byRoot[use.rootToken];
    if (known == null || use.sequence > known) {
      byRoot[use.rootToken] = use.sequence;
    }
  }
  // A window entry is also a use — a caller may hand over one list and not the
  // other, and the newest rows must not be invisible to the ordering.
  for (final use in window) {
    final byRoot = lastUseByRelation.putIfAbsent(use.relationKey, () => {});
    final known = byRoot[use.rootToken];
    if (known == null || use.sequence > known) {
      byRoot[use.rootToken] = use.sequence;
    }
  }

  final loop = <ExerciseQuestion>[];
  for (final stage in stages) {
    for (final exercise in stage.exercises) {
      // `requiresVoice` is the second half of the filter, not a redundancy:
      // a sung exercise (resolution, Epic 3) has no tap-to-answer surface, so
      // it stays out even if a caller names its type.
      if (!types.contains(exercise.type) || exercise.requiresVoice) continue;

      final pool = variantsFor(exercise);
      if (pool.isEmpty) {
        // An invariant exercise (a chord): catalog refs, verbatim, always.
        loop.add(questionFor(exercise));
        continue;
      }
      final chosen = chooseVariant(
        pool,
        window,
        lastUseByRoot: lastUseByRelation[pool.first.relationKey] ?? const {},
      );
      loop.add(questionFor(exercise, variant: chosen));
      final sequence = nextSequence++;
      window.insert(
        0,
        VariantUse(
          relationKey: chosen.relationKey,
          rootToken: chosen.rootToken,
          sequence: sequence,
        ),
      );
      if (window.length > variantWindow) window.removeLast();
      (lastUseByRelation[chosen.relationKey] ??= {})[chosen.rootToken] =
          sequence;
    }
  }
  return loop;
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
