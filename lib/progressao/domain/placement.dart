/// The starting level: the Progressão module's port over the level the
/// levelling assigns (Story 1.9), which this module owns (AD-2, single-writer).
///
/// Why here and not in `nivelamento/`: the architecture makes Progressão the
/// owner of every persisted fact about the learner's progress, and the
/// starting level is the first one Epic 2 reads — Story 2.1 opens the skill
/// tree from it. The levelling module *produces* the level and writes it
/// through this port, exactly as `exercicios/` writes the variation history
/// through `VariantHistoryRepository`; the boot gate *reads* it through
/// `placementProvider`.
///
/// Everything in this file is pure: no Drift symbol, no `AppDatabase`. The
/// implementation lives in `data/` and is library-private.
library;

import 'package:flutter/foundation.dart';

/// The level the levelling assigned, as recorded.
@immutable
class Placement {
  const Placement({
    required this.stageId,
    required this.correctCount,
    required this.recordedAt,
  });

  /// The catalog `stageId` the learner starts from (`s-tercas`, …). Opaque to
  /// this module: the levelling decides it, the skill tree resolves it.
  final String stageId;

  /// How many levelling exercises were answered correctly. Kept for Epic 2's
  /// calibration; the levelling never shows it to a learner who scored zero.
  final int correctCount;

  /// When it was recorded, in UTC.
  final DateTime recordedAt;

  @override
  bool operator ==(Object other) =>
      other is Placement &&
      other.stageId == stageId &&
      other.correctCount == correctCount &&
      other.recordedAt == recordedAt;

  @override
  int get hashCode => Object.hash(stageId, correctCount, recordedAt);

  @override
  String toString() =>
      'Placement($stageId, $correctCount correct, at $recordedAt)';
}

/// Reads and records the starting level.
///
/// Both methods may fail — the database can be unavailable — and neither
/// swallows it: the levelling decides to show its summary anyway and log, and
/// the boot gate decides what a failed read means. A repository that silently
/// said a write was fine when it was not would send a learner back through the
/// levelling on the next boot with no trace of why.
abstract interface class PlacementRepository {
  /// The recorded level, or `null` when the learner has not been levelled —
  /// which is what "first use" means (UX-DR12).
  Future<Placement?> current();

  /// Records the level, replacing any earlier one. Exactly one row afterwards.
  Future<void> record({required String stageId, required int correctCount});
}
