/// The levelling as pure data and rules (Story 1.9): which exercises are asked,
/// in what order, with which options, and what level the answers add up to.
///
/// Everything here is testable by import — no widget, no notifier, no
/// database. The notifier in `../presentation/` drives the shared exercise
/// card with what this file computes, and writes the result through the
/// Progressão port.
///
/// This module names `IntervalExercise` on purpose: Rule 6 of
/// `check_module_boundaries` keeps only `exercicios/presentation/`
/// type-agnostic, and the levelling *is* a fixed sequence of intervals by
/// human decision (2026-09-15) — the choice is written here, in code, and
/// changing it means recompiling.
library;

import 'dart:math';

import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter/foundation.dart';

/// One step of the levelling: the stage it probes and the ascending interval
/// that stands for it.
@immutable
class PlacementStep {
  const PlacementStep({
    required this.stageId,
    required this.intervalId,
    required this.nameUi,
  });

  /// The catalog `stageId` this step probes — the level the learner is placed
  /// at if this is the first step they miss.
  final String stageId;

  /// The catalog interval id asked, always ascending.
  final String intervalId;

  /// The stage's human name, shown on the summary. A table here rather than a
  /// catalog field: adding a field would move the catalog `schemaVersion`,
  /// which is Ask First since Story 1.2 (decided: it does not move).
  final String nameUi;
}

/// The seven steps, in order of difficulty, one per interval stage of the
/// catalog. Human decision, 2026-09-15.
///
/// The first is deliberately easy — a rising octave — and gets the
/// "farthest" distractors ([farthestOptionsFor]) so the unison is among them.
const List<PlacementStep> placementSequence = [
  PlacementStep(
    stageId: 's-consonancias',
    intervalId: 'P8',
    nameUi: 'Consonâncias',
  ),
  PlacementStep(stageId: 's-tercas', intervalId: 'M3', nameUi: 'Terças'),
  PlacementStep(stageId: 's-segundas', intervalId: 'M2', nameUi: 'Segundas'),
  PlacementStep(stageId: 's-quarta', intervalId: 'P4', nameUi: 'Quarta'),
  PlacementStep(stageId: 's-sextas', intervalId: 'M6', nameUi: 'Sextas'),
  PlacementStep(stageId: 's-setimas', intervalId: 'm7', nameUi: 'Sétimas'),
  PlacementStep(stageId: 's-tritono', intervalId: 'TT', nameUi: 'Trítono'),
];

/// The human name of [stageId] on the summary, or the id itself for a stage
/// the sequence does not know — never an exception on the one screen that has
/// to end well.
String stageNameFor(String stageId) {
  for (final step in placementSequence) {
    if (step.stageId == stageId) return step.nameUi;
  }
  return stageId;
}

/// A step's exercise is missing from the catalog. Raised while the sequence is
/// built, so it surfaces as the screen's retry state rather than as a card
/// that cannot play.
sealed class NivelamentoError implements Exception {
  const NivelamentoError();
}

/// [step] names an ascending interval exercise the catalog does not hold.
final class PlacementExerciseMissing extends NivelamentoError {
  const PlacementExerciseMissing(this.step);

  final PlacementStep step;

  @override
  String toString() =>
      'NivelamentoError.placementExerciseMissing: no ascending '
      '${step.intervalId} in stage ${step.stageId}';
}

/// The seven questions, in [placementSequence] order, projected off the catalog
/// with its refs verbatim — no variation, and nothing recorded in the
/// variation history: the levelling is not a practice session (AD-2).
List<ExerciseQuestion> placementLoop(Curriculum curriculum) => [
  for (final step in placementSequence)
    questionFor(_exerciseFor(curriculum, step)),
];

IntervalExercise _exerciseFor(Curriculum curriculum, PlacementStep step) {
  for (final stage in curriculum.stages) {
    if (stage.stageId != step.stageId) continue;
    for (final exercise in stage.exercises) {
      if (exercise is IntervalExercise &&
          exercise.interval.id == step.intervalId &&
          exercise.direction == Direction.asc) {
        return exercise;
      }
    }
  }
  throw PlacementExerciseMissing(step);
}

/// The distractor pool: every interval of the catalog, keyed by type as
/// `PracticeState` expects it. Same builder as the practice loop, narrowed to
/// intervals — the levelling never asks a chord or a scale.
Map<ExerciseType, List<AnswerOption>> placementPool(Curriculum curriculum) =>
    practicePool(curriculum, types: const {ExerciseType.interval});

/// The options for the question at [index] of [loop].
///
/// The first card gets the **farthest** distractors — the one place the
/// levelling departs from the practice — so the deliberately easy opener is
/// easy in its options too. Every other card is built exactly as the practice
/// builds it: the three closest, `answerOptionsForQuestion`.
List<AnswerOption> placementOptionsFor(
  List<ExerciseQuestion> loop,
  Map<ExerciseType, List<AnswerOption>> pool,
  int index,
) {
  final question = loop[index];
  if (index == 0) {
    return farthestOptionsFor(
      question.answer,
      pool[question.type] ?? const [],
      seed: question.optionSeed(index),
    );
  }
  return answerOptionsForQuestion(
    question,
    pool,
    seed: question.optionSeed(index),
  );
}

/// The mirror image of `answerOptionsFor`: the [answer] plus the 3 options of
/// [pool] **farthest** from it by `AnswerOption.distanceTo` (ties broken by
/// `id`), in a deterministic Fisher-Yates order keyed on [seed] — the same
/// shuffle, so the two functions differ in the ranking only.
///
/// For a rising octave over the 13-interval pool that is the unison, the minor
/// second and the major second: the confusions nobody makes, which is the
/// point of the first card.
List<AnswerOption> farthestOptionsFor(
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
    if (da != db) return db.compareTo(da);
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

/// What the levelling concluded: the level and, for Epic 2, the score.
@immutable
class PlacementOutcome {
  const PlacementOutcome({required this.stageId, required this.correctCount});

  /// The `stageId` the learner starts from.
  final String stageId;

  /// How many of the steps were answered correctly, `0..7`.
  final int correctCount;

  /// The level's human name for the summary.
  String get stageNameUi => stageNameFor(stageId);

  @override
  bool operator ==(Object other) =>
      other is PlacementOutcome &&
      other.stageId == stageId &&
      other.correctCount == correctCount;

  @override
  int get hashCode => Object.hash(stageId, correctCount);

  @override
  String toString() => 'PlacementOutcome($stageId, $correctCount correct)';
}

/// The level rule (human decision, 2026-09-15): the stage of the **first**
/// step answered wrong; every step right → the last stage (`s-tritono`); the
/// first step wrong — which includes zero right — → the first stage
/// (`s-consonancias`).
///
/// [attempts] are the levelling's answers in [placementSequence] order, one
/// per step. A shorter list is read as far as it goes: an unanswered step is
/// neither right nor wrong, so the level is the first miss among the answered
/// ones, or the last stage *answered* rather than the last of the sequence —
/// a learner is never placed past what they were actually asked.
PlacementOutcome placementOutcomeFor(List<ExerciseAttempt> attempts) {
  final answered = min(attempts.length, placementSequence.length);
  var correct = 0;
  String? firstMiss;
  for (var i = 0; i < answered; i++) {
    if (attempts[i].wasCorrect) {
      correct++;
    } else {
      firstMiss ??= placementSequence[i].stageId;
    }
  }
  final stageId =
      firstMiss ??
      (answered == 0
          ? placementSequence.first.stageId
          : placementSequence[answered - 1].stageId);
  return PlacementOutcome(stageId: stageId, correctCount: correct);
}
