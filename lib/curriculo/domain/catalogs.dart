/// Resolved catalog entries (`*Spec`) — pure data classes, no ORM annotation.
///
/// Each `*Spec` carries the descriptive fields for one interval / chord / scale
/// / cadence id used by the catalog. Exercises reference these by id; the
/// repository resolves the id and hands back the [IntervalSpec] / [ChordSpec] /
/// [ScaleSpec] / [CadenceSpec] on the domain model.
library;

import 'package:flutter/foundation.dart';

/// One entry of `intervalCatalog`.
@immutable
class IntervalSpec {
  const IntervalSpec({
    required this.id,
    required this.semitones,
    required this.nameUi,
    required this.abbr,
    required this.quality,
  });

  final String id;
  final int semitones;
  final String nameUi;
  final String abbr;
  final String quality;

  @override
  bool operator ==(Object other) =>
      other is IntervalSpec &&
      other.id == id &&
      other.semitones == semitones &&
      other.nameUi == nameUi &&
      other.abbr == abbr &&
      other.quality == quality;

  @override
  int get hashCode => Object.hash(id, semitones, nameUi, abbr, quality);
}

/// One entry of `chordCatalog`.
@immutable
class ChordSpec {
  const ChordSpec({
    required this.id,
    required this.nameUi,
    required this.intervals,
    required this.inversion,
  });

  final String id;
  final String nameUi;

  /// Semitone offsets from the root (e.g. `[4, 7]` for a major triad).
  final List<int> intervals;

  /// `0` = root position. `1|2` reserved for post-v1.
  final int inversion;

  @override
  bool operator ==(Object other) =>
      other is ChordSpec &&
      other.id == id &&
      other.nameUi == nameUi &&
      listEquals(other.intervals, intervals) &&
      other.inversion == inversion;

  @override
  int get hashCode =>
      Object.hash(id, nameUi, Object.hashAll(intervals), inversion);
}

/// One entry of `scaleCatalog`.
@immutable
class ScaleSpec {
  const ScaleSpec({
    required this.id,
    required this.nameUi,
    required this.steps,
  });

  final String id;
  final String nameUi;

  /// Semitone steps between successive degrees (e.g. major = `2,2,1,2,2,2,1`).
  final List<int> steps;

  @override
  bool operator ==(Object other) =>
      other is ScaleSpec &&
      other.id == id &&
      other.nameUi == nameUi &&
      listEquals(other.steps, steps);

  @override
  int get hashCode => Object.hash(id, nameUi, Object.hashAll(steps));
}

/// One entry of `cadenceCatalog`.
@immutable
class CadenceSpec {
  const CadenceSpec({
    required this.id,
    required this.nameUi,
    required this.degrees,
  });

  final String id;
  final String nameUi;

  /// Roman-numeral degrees of the progression (e.g. `["V", "I"]`).
  final List<String> degrees;

  @override
  bool operator ==(Object other) =>
      other is CadenceSpec &&
      other.id == id &&
      other.nameUi == nameUi &&
      listEquals(other.degrees, degrees);

  @override
  int get hashCode => Object.hash(id, nameUi, Object.hashAll(degrees));
}
