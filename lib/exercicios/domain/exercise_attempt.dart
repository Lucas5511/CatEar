/// One recorded answer to a recognition exercise.
///
/// Immutable value object. Its enums (`ExerciseType`, `ErrorType`) come from the
/// `curriculo` module (AR-4 / AR-8) — never a free string. Story 1.4 only
/// builds and logs these (`dart:developer`); persistence and the
/// `SessionResultReported` event are Story 1.7 / 1.8.
library;

import 'package:catear/curriculo/curriculo.dart';
import 'package:flutter/foundation.dart';

/// The outcome of a single tap-to-answer attempt.
@immutable
class ExerciseAttempt {
  const ExerciseAttempt({
    required this.exerciseType,
    required this.wasCorrect,
    required this.reactionTimeMs,
    this.errorType,
  }) : assert(
         wasCorrect ? errorType == null : true,
         'a correct attempt carries no errorType',
       ),
       assert(reactionTimeMs > 0, 'reaction time is always > 0');

  /// Which kind of exercise this attempt belongs to. Always
  /// [ExerciseType.interval] in Story 1.4.
  final ExerciseType exerciseType;

  /// `true` when the chosen option matched the exercise's answer.
  final bool wasCorrect;

  /// The confused concept on a wrong answer — the [ErrorType] whose `.id`
  /// equals the picked option's `IntervalSpec.id`. `null` on a correct answer.
  final ErrorType? errorType;

  /// Milliseconds from the moment the options enabled (first playback done) to
  /// the first tap. Always `> 0`.
  final int reactionTimeMs;

  /// Builds an attempt for an interval exercise, resolving [errorType] from the
  /// picked option on a wrong answer.
  factory ExerciseAttempt.forInterval({
    required IntervalSpec answer,
    required IntervalSpec picked,
    required int reactionTimeMs,
  }) {
    final correct = picked.id == answer.id;
    return ExerciseAttempt(
      exerciseType: ExerciseType.interval,
      wasCorrect: correct,
      reactionTimeMs: reactionTimeMs,
      errorType: correct ? null : errorTypeForIntervalId(picked.id),
    );
  }

  /// The [ErrorType] whose wire id matches [intervalId] (`P1`..`P8` map 1:1).
  static ErrorType errorTypeForIntervalId(String intervalId) =>
      ErrorType.values.firstWhere(
        (e) => e.id == intervalId,
        orElse: () => throw ArgumentError.value(
          intervalId,
          'intervalId',
          'no ErrorType with this id',
        ),
      );

  @override
  bool operator ==(Object other) =>
      other is ExerciseAttempt &&
      other.exerciseType == exerciseType &&
      other.wasCorrect == wasCorrect &&
      other.errorType == errorType &&
      other.reactionTimeMs == reactionTimeMs;

  @override
  int get hashCode =>
      Object.hash(exerciseType, wasCorrect, errorType, reactionTimeMs);

  @override
  String toString() =>
      'ExerciseAttempt(exerciseType: $exerciseType, wasCorrect: $wasCorrect, '
      'errorType: $errorType, reactionTimeMs: $reactionTimeMs)';
}
