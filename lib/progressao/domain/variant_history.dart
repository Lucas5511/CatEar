/// The recent-variation history: the Progressão module's port over the state it
/// owns (AD-2, single-writer).
///
/// Why here and not in `exercicios/`: the epic's architecture makes Progressão
/// the owner of "what has already been practised". Story 1.8 needs the smallest
/// slice of that — a log of which variation of which relation was heard, and
/// when — so it creates that slice here rather than a second home for progress
/// state that Story 2.1 would then have to unify.
///
/// Everything in this file is pure: no Drift symbol, no `AppDatabase`. The
/// implementation lives in `data/` and is library-private; `exercicios/`
/// reaches it only through the `progressao.dart` barrel.
library;

import 'package:flutter/foundation.dart';

/// One recorded presentation of one exercise variation.
@immutable
class VariantUse {
  const VariantUse({
    required this.relationKey,
    required this.rootToken,
    required this.sequence,
  });

  /// The musical relation, independent of the root it was played from — e.g.
  /// `interval:M3:asc`. Built by `exercicios/domain/exercise_variation.dart`;
  /// opaque to this module, which only ever compares it for equality.
  final String relationKey;

  /// The `audioSampleRef` of the root the relation was played from.
  final String rootToken;

  /// Monotonic recency: a larger [sequence] happened later.
  ///
  /// Not a timestamp. The window and the least-recently-used fallback both
  /// need a total order that no clock change can scramble.
  final int sequence;

  @override
  bool operator ==(Object other) =>
      other is VariantUse &&
      other.relationKey == relationKey &&
      other.rootToken == rootToken &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(relationKey, rootToken, sequence);

  @override
  String toString() => 'VariantUse($relationKey @ $rootToken #$sequence)';
}

/// Reads and appends the recent-variation history.
///
/// Both methods may fail — the database can be unavailable — and neither
/// swallows it: the anti-decoreba rule is a *preference*, so the caller decides
/// to degrade (practise with no history) rather than have a repository decide
/// silently that a write was fine when it was not.
abstract interface class VariantHistoryRepository {
  /// The [limit] most recently recorded variations, **newest first**.
  Future<List<VariantUse>> recent({required int limit});

  /// The most recent use of **every** (relation, root) pair still retained —
  /// one entry per pair, carrying the sequence of its latest use.
  ///
  /// Separate from [recent] because the two answer different questions. The
  /// window says what may *not* play; this says how long ago each of the rest
  /// last played, which is what makes the choice walk a relation's pool instead
  /// of alternating between its two lowest roots. It reaches past the window
  /// on purpose.
  Future<List<VariantUse>> lastUsePerRoot();

  /// Appends one presentation.
  ///
  /// Writes are serialised in call order, so a caller may fire them without
  /// awaiting and still get a faithful history.
  Future<void> record({required String relationKey, required String rootToken});
}
