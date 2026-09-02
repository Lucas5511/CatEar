/// Pure domain models for the curriculum catalog.
///
/// Data classes with `==` / `hashCode`, zero ORM annotation. The repository
/// maps the JSON asset onto these and never leaks its origin.
library;

import 'package:flutter/foundation.dart';

import 'catalogs.dart';
import 'enums.dart';

/// The whole catalog, version-stamped.
@immutable
class Curriculum {
  const Curriculum({
    required this.schemaVersion,
    required this.stages,
    required this.errorTypes,
  });

  final int schemaVersion;
  final List<Stage> stages;

  /// Canonical error taxonomy — exactly the set of [ErrorType] values.
  final Set<ErrorType> errorTypes;

  @override
  bool operator ==(Object other) =>
      other is Curriculum &&
      other.schemaVersion == schemaVersion &&
      listEquals(other.stages, stages) &&
      setEquals(other.errorTypes, errorTypes);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    Object.hashAll(stages),
    Object.hashAllUnordered(errorTypes),
  );
}

/// One skill-tree stage.
@immutable
class Stage {
  const Stage({
    required this.stageId,
    required this.order,
    required this.scaffoldIntensity,
    required this.timbreScaffold,
    required this.exercises,
  });

  final String stageId;
  final int order;

  /// Colour-scaffold intensity, `0.0`–`1.0`. `null` = "not applicable" — the
  /// stage is **excluded** from the fading subsequence (≠ `0.0`).
  final double? scaffoldIntensity;

  /// Per-stage timbre scaffold, or `null` when unspecified.
  final TimbreScaffold? timbreScaffold;

  final List<Exercise> exercises;

  @override
  bool operator ==(Object other) =>
      other is Stage &&
      other.stageId == stageId &&
      other.order == order &&
      other.scaffoldIntensity == scaffoldIntensity &&
      other.timbreScaffold == timbreScaffold &&
      listEquals(other.exercises, exercises);

  @override
  int get hashCode => Object.hash(
    stageId,
    order,
    scaffoldIntensity,
    timbreScaffold,
    Object.hashAll(exercises),
  );
}

/// A single exercise. `requiresVoice` is `true` **only** on
/// [ResolutionExercise] — the inert flag the Epic 3 vocal work switches on.
@immutable
sealed class Exercise {
  const Exercise({required this.audioSampleRefs, required this.requiresVoice});

  /// Opaque sample tokens (`^[a-z0-9_]+$`), non-empty. Their concrete meaning
  /// is resolved by the `audio` module (Stories 1.3 / 1.3b).
  final List<String> audioSampleRefs;

  /// `true` iff this is a [ResolutionExercise].
  final bool requiresVoice;

  ExerciseType get type;
}

/// Interval recognition, in a given [direction].
@immutable
final class IntervalExercise extends Exercise {
  const IntervalExercise({
    required this.interval,
    required this.direction,
    required super.audioSampleRefs,
  }) : super(requiresVoice: false);

  final IntervalSpec interval;
  final Direction direction;

  @override
  ExerciseType get type => ExerciseType.interval;

  @override
  bool operator ==(Object other) =>
      other is IntervalExercise &&
      other.interval == interval &&
      other.direction == direction &&
      listEquals(other.audioSampleRefs, audioSampleRefs);

  @override
  int get hashCode =>
      Object.hash(interval, direction, Object.hashAll(audioSampleRefs));
}

/// Scale recognition, in a given [direction].
@immutable
final class ScaleExercise extends Exercise {
  const ScaleExercise({
    required this.scale,
    required this.direction,
    required super.audioSampleRefs,
  }) : super(requiresVoice: false);

  final ScaleSpec scale;
  final Direction direction;

  @override
  ExerciseType get type => ExerciseType.scale;

  @override
  bool operator ==(Object other) =>
      other is ScaleExercise &&
      other.scale == scale &&
      other.direction == direction &&
      listEquals(other.audioSampleRefs, audioSampleRefs);

  @override
  int get hashCode =>
      Object.hash(scale, direction, Object.hashAll(audioSampleRefs));
}

/// Chord-quality recognition (root position in v1).
@immutable
final class ChordExercise extends Exercise {
  const ChordExercise({required this.chord, required super.audioSampleRefs})
    : super(requiresVoice: false);

  final ChordSpec chord;

  @override
  ExerciseType get type => ExerciseType.chord;

  @override
  bool operator ==(Object other) =>
      other is ChordExercise &&
      other.chord == chord &&
      listEquals(other.audioSampleRefs, audioSampleRefs);

  @override
  int get hashCode => Object.hash(chord, Object.hashAll(audioSampleRefs));
}

/// Cadence resolution — the user sings the tonic. Always `requiresVoice: true`;
/// inert in the skill tree / session generation until Epic 3.
@immutable
final class ResolutionExercise extends Exercise {
  const ResolutionExercise({
    required this.cadence,
    required super.audioSampleRefs,
  }) : super(requiresVoice: true);

  final CadenceSpec cadence;

  @override
  ExerciseType get type => ExerciseType.resolution;

  @override
  bool operator ==(Object other) =>
      other is ResolutionExercise &&
      other.cadence == cadence &&
      listEquals(other.audioSampleRefs, audioSampleRefs);

  @override
  int get hashCode => Object.hash(cadence, Object.hashAll(audioSampleRefs));
}
