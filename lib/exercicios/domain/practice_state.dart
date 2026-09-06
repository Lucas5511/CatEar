/// The practice loop's state, as a pure value.
///
/// Lives in `domain/` — not next to the widgets — because the presentation
/// layer is held type-agnostic by `check_module_boundaries` Rule 6, and a state
/// object is where a type leaks back in first. It holds only
/// [ExerciseQuestion] / [AnswerOption], never a catalog spec.
library;

import 'package:catear/curriculo/curriculo.dart';
import 'package:flutter/foundation.dart';

import 'exercise_attempt.dart';
import 'exercise_question.dart';

/// Where the loop is in answering the current exercise.
enum AnswerPhase { answering, correct, incorrect, finished }

const Object _keep = Object();

/// Immutable snapshot of the fixed practice loop.
@immutable
class PracticeState {
  PracticeState({
    required List<ExerciseQuestion> loop,
    required Map<ExerciseType, List<AnswerOption>> pool,
    required this.index,
    required List<AnswerOption> options,
    required this.phase,
    required List<ExerciseAttempt> attempts,
    this.picked,
  }) : loop = List.unmodifiable(loop),
       // Deep: `Map.unmodifiable` freezes the map, not the lists inside it,
       // and `pool[type]` is handed straight to callers.
       pool = Map.unmodifiable({
         for (final entry in pool.entries)
           entry.key: List<AnswerOption>.unmodifiable(entry.value),
       }),
       options = List.unmodifiable(options),
       attempts = List.unmodifiable(attempts);

  /// Every question of the loop, in stage order (39 in v1: 23 intervals,
  /// 8 chords, 8 scales).
  final List<ExerciseQuestion> loop;

  /// The distractor pool, one list per type (13 / 4 / 4 in v1). Keyed by type
  /// so a question's alternatives can never be drawn from another catalog.
  final Map<ExerciseType, List<AnswerOption>> pool;

  /// Position in [loop].
  final int index;

  /// The 4 (or fewer) options for the current exercise, in display order.
  final List<AnswerOption> options;

  final AnswerPhase phase;

  /// Attempts recorded so far, one per answered exercise. In-memory only;
  /// Story 1.7 consumes these.
  final List<ExerciseAttempt> attempts;

  /// The option the user tapped, once answered.
  final AnswerOption? picked;

  ExerciseQuestion get current => loop[index];
  AnswerOption get answer => current.answer;

  PracticeState copyWith({
    int? index,
    List<AnswerOption>? options,
    AnswerPhase? phase,
    List<ExerciseAttempt>? attempts,
    Object? picked = _keep,
  }) => PracticeState(
    loop: loop,
    pool: pool,
    index: index ?? this.index,
    options: options ?? this.options,
    phase: phase ?? this.phase,
    attempts: attempts ?? this.attempts,
    picked: identical(picked, _keep) ? this.picked : picked as AnswerOption?,
  );
}
