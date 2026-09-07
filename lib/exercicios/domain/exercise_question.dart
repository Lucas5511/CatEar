/// The type-agnostic answer model the practice flow is built on (Story 1.5a).
///
/// The presentation layer never sees an `IntervalSpec` / `ChordSpec` /
/// `ScaleSpec`. It sees an [ExerciseQuestion]: a prompt, the sample refs to
/// play, and [AnswerOption]s to choose between — a shape that is identical for
/// intervals, chords and scales. Everything that differs per [ExerciseType]
/// (which catalog spec supplies the answer, which prompt is asked, how far
/// apart two answers are) is decided here, in `domain/`, by [questionFor].
///
/// `tool/check_module_boundaries.dart` Rule 6 keeps it that way: no file under
/// `lib/exercicios/presentation/` may name any catalog exercise type or spec —
/// all eight, not just the interval pair, because a duplicated tree would be
/// written against the types Story 1.5 adds. That static rule — not a widget
/// test — is what stops the widget tree from being copied once per type.
library;

import 'dart:math' as math;

import 'package:catear/curriculo/curriculo.dart';
import 'package:flutter/foundation.dart';

import 'motif.dart';

/// One selectable answer, projected off a catalog spec.
///
/// Everything the UI needs is [id] (identity) and [nameUi] (the label). The
/// [semitoneProfile] is the single generic handle the machinery keeps on the
/// music itself.
@immutable
class AnswerOption {
  AnswerOption({
    required this.id,
    required this.nameUi,
    required List<int> semitoneProfile,
  }) : semitoneProfile = List.unmodifiable(semitoneProfile);

  /// Catalog id of the underlying spec (`"M3"`, `"major"`, `"dorian"`).
  ///
  /// Unique only **within one [ExerciseType]**: `chordCatalog` and
  /// `scaleCatalog` both carry a `"major"`. Nothing may resolve an id without
  /// knowing its type — see `ExerciseAttempt.errorTypeFor`.
  final String id;

  /// The label shown on the option button and in the result line.
  final String nameUi;

  /// Semitone offsets above the reference pitch: `[4]` for a major third,
  /// `[4, 7]` for a major triad, `[2, 4, 5, 7, 9, 11, 12]` for the major scale.
  ///
  /// Distractor ranking and the scale error taxonomy both read it, so a new
  /// exercise type only has to answer "where do your notes sit" to get both.
  final List<int> semitoneProfile;

  /// Sum of the per-position semitone differences against [other].
  ///
  /// For intervals — one-element profiles — this is exactly
  /// `|semitones - other.semitones|`, so the Story 1.4 distractor ranking is
  /// preserved unchanged.
  int distanceTo(AnswerOption other) {
    final length = math.max(
      semitoneProfile.length,
      other.semitoneProfile.length,
    );
    var total = 0;
    for (var i = 0; i < length; i++) {
      final a = i < semitoneProfile.length ? semitoneProfile[i] : 0;
      final b = i < other.semitoneProfile.length ? other.semitoneProfile[i] : 0;
      total += (a - b).abs();
    }
    return total;
  }

  /// The [semitoneProfile] positions where this option and [other] disagree.
  ///
  /// For scales the position is the degree, offset by two (index `0` is the
  /// 2nd degree): a single disagreement is what turns "major vs mixolydian"
  /// into "the 7th is altered".
  List<int> differingProfileIndices(AnswerOption other) {
    final length = math.max(
      semitoneProfile.length,
      other.semitoneProfile.length,
    );
    final differing = <int>[];
    for (var i = 0; i < length; i++) {
      final a = i < semitoneProfile.length ? semitoneProfile[i] : null;
      final b = i < other.semitoneProfile.length
          ? other.semitoneProfile[i]
          : null;
      if (a != b) differing.add(i);
    }
    return differing;
  }

  @override
  bool operator ==(Object other) =>
      other is AnswerOption &&
      other.id == id &&
      other.nameUi == nameUi &&
      listEquals(other.semitoneProfile, semitoneProfile);

  @override
  int get hashCode => Object.hash(id, nameUi, Object.hashAll(semitoneProfile));

  @override
  String toString() => 'AnswerOption($id)';
}

/// One exercise as the practice flow sees it: what to ask, what to play, and
/// what the right answer is.
@immutable
class ExerciseQuestion {
  ExerciseQuestion({
    required this.type,
    required this.prompt,
    required this.answer,
    required List<String> audioSampleRefs,
    required List<MotifEvent> motif,
    this.variantKey,
  }) : audioSampleRefs = List.unmodifiable(audioSampleRefs),
       motif = List.unmodifiable(motif);

  /// Kept for the recorded [ExerciseType] of an attempt and for resolving the
  /// error taxonomy. The widgets never branch on it.
  final ExerciseType type;

  /// The question shown above the player — from [exercisePrompts].
  final String prompt;

  /// The correct option. Also the option the result line names.
  final AnswerOption answer;

  /// Opaque sample tokens, already ordered. Kept for diagnostics and for the
  /// error banner; what actually gets played is [motif].
  final List<String> audioSampleRefs;

  /// The musical shape this question is heard as — the sequence of sample fires
  /// and their rhythm, decided per type by [questionFor] (Story 1.5).
  ///
  /// `PhrasePlayer` plays whatever it is handed. Making the contour data rather
  /// than a `switch` inside the player is what keeps the presentation layer free
  /// of per-type code, which Rule 6 cannot enforce on its own.
  final List<MotifEvent> motif;

  /// Wall time of one [motif] playback.
  Duration get motifTotal => motifDuration(motif);

  /// What separates two exercises that share an [answer] — the melodic
  /// direction in v1, `null` for a type that has none. Folded into
  /// [optionSeed] so an ascending and a descending M3 do not get the same
  /// option order.
  final Object? variantKey;

  /// Deterministic shuffle seed for this question at loop position [index].
  ///
  /// Same shape as Story 1.4's `Object.hash(interval.id, direction, index)`, so
  /// the option order the learner sees for every interval is byte-identical.
  int optionSeed(int index) => Object.hash(answer.id, variantKey, index);

  @override
  bool operator ==(Object other) =>
      other is ExerciseQuestion &&
      other.type == type &&
      other.prompt == prompt &&
      other.answer == answer &&
      listEquals(other.audioSampleRefs, audioSampleRefs) &&
      listEquals(other.motif, motif) &&
      other.variantKey == variantKey;

  @override
  int get hashCode => Object.hash(
    type,
    prompt,
    answer,
    Object.hashAll(audioSampleRefs),
    Object.hashAll(motif),
    variantKey,
  );

  @override
  String toString() => 'ExerciseQuestion($type, ${answer.id})';
}

/// The prompt asked per exercise type.
///
/// A table here in `domain/` rather than a catalog field: adding a field would
/// move the catalog `schemaVersion`, which is Ask First since Story 1.2
/// (human decision, 2026-09-05).
const Map<ExerciseType, String> exercisePrompts = {
  ExerciseType.interval: 'Que intervalo é este?',
  ExerciseType.chord: 'Que acorde é este?',
  ExerciseType.scale: 'Que escala é esta?',
  ExerciseType.resolution: 'Que cadência é esta?',
};

/// Projects one catalog [Exercise] onto the type-agnostic model.
///
/// This switch is the **single** place the sealed `Exercise` hierarchy is taken
/// apart. Adding an exercise type means adding a branch here, not a widget.
ExerciseQuestion questionFor(Exercise exercise) => switch (exercise) {
  IntervalExercise() => ExerciseQuestion(
    type: ExerciseType.interval,
    prompt: exercisePrompts[ExerciseType.interval]!,
    answer: AnswerOption(
      id: exercise.interval.id,
      nameUi: exercise.interval.nameUi,
      semitoneProfile: [exercise.interval.semitones],
    ),
    audioSampleRefs: exercise.audioSampleRefs,
    // `r0, r1, r0` — unchanged since Story 1.4.
    motif: intervalMotif(exercise.audioSampleRefs),
    variantKey: exercise.direction,
  ),
  ChordExercise() => ExerciseQuestion(
    type: ExerciseType.chord,
    prompt: exercisePrompts[ExerciseType.chord]!,
    answer: AnswerOption(
      id: exercise.chord.id,
      nameUi: exercise.chord.nameUi,
      // Already semitone offsets above the root: [4, 7] for a major triad.
      semitoneProfile: exercise.chord.intervals,
    ),
    audioSampleRefs: exercise.audioSampleRefs,
    // Block -> arpeggio -> block, off the positional ref contract Story 1.4b
    // wrote: `[block, root, third, fifth]`.
    motif: chordMotif(exercise.audioSampleRefs),
  ),
  ScaleExercise() => ExerciseQuestion(
    type: ExerciseType.scale,
    prompt: exercisePrompts[ExerciseType.scale]!,
    answer: AnswerOption(
      id: exercise.scale.id,
      nameUi: exercise.scale.nameUi,
      semitoneProfile: degreesFromSteps(exercise.scale.steps),
    ),
    audioSampleRefs: exercise.audioSampleRefs,
    // All 8 notes in the order the catalog stores them (`direction` is already
    // applied to the refs), at scale pace.
    motif: scaleMotif(exercise.audioSampleRefs),
    variantKey: exercise.direction,
  ),
  ResolutionExercise() => ExerciseQuestion(
    type: ExerciseType.resolution,
    prompt: exercisePrompts[ExerciseType.resolution]!,
    answer: AnswerOption(
      id: exercise.cadence.id,
      nameUi: exercise.cadence.nameUi,
      // A cadence is a degree progression, not a pitch set: no profile, so
      // every pair sits at distance 0 and every error resolves to `far-miss`.
      semitoneProfile: const [],
    ),
    audioSampleRefs: exercise.audioSampleRefs,
    // No contour. A cadence is sung (Epic 3) and `requiresVoice` keeps it out
    // of the tap loop, so nothing plays it today — and pacing two chords is a
    // musical decision this story has no basis to make. Story 3.5, which turns
    // resolution on, gives it one; until then an empty motif surfaces the
    // audio banner rather than inventing a rhythm nobody chose.
    motif: const [],
  ),
};

/// Turns a scale's successive `steps` into semitone offsets above the tonic.
///
/// `[2, 2, 1, 2, 2, 2, 1]` (major) becomes `[2, 4, 5, 7, 9, 11, 12]`, so index
/// `0` is the 2nd degree and index `5` the 7th. Comparing two scales position
/// by position then says exactly which degree was altered.
List<int> degreesFromSteps(List<int> steps) {
  final degrees = <int>[];
  var running = 0;
  for (final step in steps) {
    running += step;
    degrees.add(running);
  }
  return degrees;
}
