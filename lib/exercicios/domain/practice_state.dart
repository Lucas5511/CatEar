/// The practice loop's state, as a pure value.
///
/// Lives in `domain/` — not next to the widgets — because the presentation
/// layer is held type-agnostic by `check_module_boundaries` Rule 6, and a state
/// object is where a type leaks back in first. It holds only
/// [ExerciseQuestion] / [AnswerOption], never a catalog spec.
library;

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
    required List<AnswerOption> pool,
    required this.index,
    required List<AnswerOption> options,
    required this.phase,
    required List<ExerciseAttempt> attempts,
    this.picked,
  }) : loop = List.unmodifiable(loop),
       pool = List.unmodifiable(pool),
       options = List.unmodifiable(options),
       attempts = List.unmodifiable(attempts);

  /// Every question of the loop, in stage order (23 intervals in v1).
  final List<ExerciseQuestion> loop;

  /// The distinct [AnswerOption] distractor pool (13 in v1).
  final List<AnswerOption> pool;

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
