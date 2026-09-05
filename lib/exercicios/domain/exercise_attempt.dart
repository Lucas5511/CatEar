/// One recorded answer to a recognition exercise.
///
/// Immutable value object. Its enums (`ExerciseType`, `ErrorType`) come from the
/// `curriculo` module (AR-4 / AR-8) — never a free string. Story 1.4 only
/// builds and logs these (`dart:developer`); persistence and the
/// `SessionResultReported` event are Story 1.7 / 1.8.
library;

import 'package:catear/curriculo/curriculo.dart';
import 'package:flutter/foundation.dart';

import 'exercise_question.dart';

/// The 13 interval [ErrorType]s, whose ids match `intervalCatalog` ids 1:1.
const Set<ErrorType> intervalErrorTypes = {
  ErrorType.p1,
  ErrorType.m2,
  ErrorType.majorSecond,
  ErrorType.m3,
  ErrorType.majorThird,
  ErrorType.p4,
  ErrorType.tritone,
  ErrorType.p5,
  ErrorType.m6,
  ErrorType.majorSixth,
  ErrorType.m7,
  ErrorType.majorSeventh,
  ErrorType.p8,
};

/// The 4 chord-quality [ErrorType]s, whose ids match `chordCatalog` ids 1:1.
const Set<ErrorType> chordErrorTypes = {
  ErrorType.major,
  ErrorType.minor,
  ErrorType.diminished,
  ErrorType.augmented,
};

/// The scale [ErrorType]s, keyed by the scale degree that was altered.
///
/// Index into a scale's semitone profile is `degree - 2` (see
/// [degreesFromSteps]).
const Map<int, ErrorType> scaleErrorTypeByDegree = {
  3: ErrorType.tercaAlterada,
  6: ErrorType.sextaAlterada,
  7: ErrorType.setimaAlterada,
};

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
  /// [ExerciseType.interval] while the loop is interval-only (Story 1.5 flips
  /// that); the resolution below is written for every type already.
  final ExerciseType exerciseType;

  /// `true` when the chosen option matched the exercise's answer.
  final bool wasCorrect;

  /// The confused concept on a wrong answer, from the canonical taxonomy.
  /// `null` on a correct answer. Never an exception: an unmapped pair is
  /// [ErrorType.farMiss], because this runs mid-session, outside any
  /// `AsyncValue.error`.
  final ErrorType? errorType;

  /// Milliseconds from the moment the options enabled (first playback done) to
  /// the first tap. Always `> 0`.
  final int reactionTimeMs;

  /// Builds an attempt for any exercise type, resolving [errorType] from the
  /// (answer, picked) pair on a wrong answer.
  factory ExerciseAttempt.forAnswer({
    required ExerciseType exerciseType,
    required AnswerOption answer,
    required AnswerOption picked,
    required int reactionTimeMs,
  }) {
    final correct = picked.id == answer.id;
    return ExerciseAttempt(
      exerciseType: exerciseType,
      wasCorrect: correct,
      reactionTimeMs: reactionTimeMs,
      errorType: correct
          ? null
          : errorTypeFor(
              exerciseType: exerciseType,
              answer: answer,
              picked: picked,
            ),
    );
  }

  /// Resolves the [ErrorType] for a wrong (answer, picked) pair.
  ///
  /// Resolution is **per [ExerciseType]**, never a global lookup by id:
  /// `scaleCatalog` has an `id: "major"` while [ErrorType.major] means *chord
  /// quality*, so a global lookup would file a scale mistake as a chord
  /// mistake. Each type searches only its own slice of the taxonomy.
  ///
  /// Anything without a mapping resolves to [ErrorType.farMiss] — this is
  /// called in the middle of a session, so it must never throw.
  static ErrorType errorTypeFor({
    required ExerciseType exerciseType,
    required AnswerOption answer,
    required AnswerOption picked,
  }) => switch (exerciseType) {
    ExerciseType.interval => _withinSet(intervalErrorTypes, picked.id),
    ExerciseType.chord => _withinSet(chordErrorTypes, picked.id),
    ExerciseType.scale => _scaleErrorType(answer, picked),
    // Resolution exercises are sung, not tapped (Epic 3) and have no taxonomy.
    ExerciseType.resolution => ErrorType.farMiss,
  };

  /// The member of [allowed] whose wire id is [id], or [ErrorType.farMiss].
  static ErrorType _withinSet(Set<ErrorType> allowed, String id) =>
      allowed.firstWhere((e) => e.id == id, orElse: () => ErrorType.farMiss);

  /// A scale error is a function of the pair, not of the picked id: if the two
  /// modes differ in exactly one degree, that degree names the error (3rd,
  /// 6th, 7th); every other shape is a [ErrorType.farMiss].
  static ErrorType _scaleErrorType(AnswerOption answer, AnswerOption picked) {
    // `degree = index + 2` only holds while both profiles describe the same
    // number of degrees. Comparing a 7-degree mode with, say, a pentatonic
    // would name the wrong degree, so unequal shapes are a far-miss by
    // decision rather than by the padding in `differingProfileIndices`.
    if (answer.semitoneProfile.length != picked.semitoneProfile.length) {
      return ErrorType.farMiss;
    }
    final differing = answer.differingProfileIndices(picked);
    if (differing.length != 1) return ErrorType.farMiss;
    // Profile index 0 is the 2nd degree.
    return scaleErrorTypeByDegree[differing.single + 2] ?? ErrorType.farMiss;
  }

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
