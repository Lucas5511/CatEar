/// The frozen taxonomy of the `curriculo` module.
///
/// `ExerciseType`, `ErrorType`, `Direction` and `TimbreScaffold` are defined
/// **only here** (and consumed by the catalog). No other module invents values.
/// Every parser throws [CurriculumError.unknownValue] on an unrecognised token
/// — never a silent fallback.
library;

import 'curriculum_error.dart';

/// Kind of recognition exercise. Ids match the JSON `exerciseType` field.
enum ExerciseType {
  interval,
  chord,
  scale,
  resolution;

  /// Parses the JSON `exerciseType` token.
  static ExerciseType fromJson(String field, String value) {
    for (final t in ExerciseType.values) {
      if (t.name == value) return t;
    }
    throw CurriculumError.unknownValue(field, value);
  }
}

/// Melodic direction of an interval or scale exercise.
enum Direction {
  asc,
  desc;

  /// Parses the JSON `direction` token.
  static Direction fromJson(String field, String value) {
    for (final d in Direction.values) {
      if (d.name == value) return d;
    }
    throw CurriculumError.unknownValue(field, value);
  }
}

/// Per-stage timbre scaffold. `clean` = no vibrato (stable pitch, for early
/// stages); `vibrato` = realistic vibrato (advanced). Non-increasing in
/// "cleanliness" across stages (see `tool/check_curriculum.dart` R3).
enum TimbreScaffold {
  clean,
  vibrato;

  /// Parses the JSON `timbreScaffold` token.
  static TimbreScaffold fromJson(String field, String value) {
    for (final t in TimbreScaffold.values) {
      if (t.name == value) return t;
    }
    throw CurriculumError.unknownValue(field, value);
  }
}

/// Canonical error taxonomy (content-model §8): what the user answered when
/// they got it wrong. The multiple-choice UI and `SessionResultReported`'s
/// `errorType` only ever use values from here.
enum ErrorType {
  p1('P1'),
  m2('m2'),
  majorSecond('M2'),
  m3('m3'),
  majorThird('M3'),
  p4('P4'),
  tritone('TT'),
  p5('P5'),
  m6('m6'),
  majorSixth('M6'),
  m7('m7'),
  majorSeventh('M7'),
  p8('P8'),
  major('major'),
  minor('minor'),
  diminished('diminished'),
  augmented('augmented'),
  octaveError('octave-error'),
  farMiss('far-miss');

  const ErrorType(this.id);

  /// Wire id as it appears in the JSON `errorTypes` list.
  final String id;

  /// Parses one JSON `errorTypes` token.
  static ErrorType fromJson(String field, String value) {
    for (final e in ErrorType.values) {
      if (e.id == value) return e;
    }
    throw CurriculumError.unknownValue(field, value);
  }
}
