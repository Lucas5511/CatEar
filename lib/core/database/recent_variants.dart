/// The first real table of the CatEar database (Story 1.8): the recent-variation
/// history the anti-decoreba rule reads.
///
/// It lives under `core/database/` because Rule 2 of
/// `tool/check_module_boundaries.dart` keeps every Drift symbol inside `core/`.
/// The *owner* of the data is the Progressão module (AD-2, single-writer): it
/// reaches this DAO through the `core.dart` barrel, maps the rows onto its own
/// pure `VariantUse`, and is the only module that writes them. Story 2.1
/// extends that module without reopening this file.
///
/// The DAO deliberately returns records rather than the Drift-generated row
/// class: `RecentVariant` is a generated symbol, and generated symbols never
/// leave `core/`.
library;

import 'package:drift/drift.dart';

import 'app_database.dart';

part 'recent_variants.g.dart';

/// One presentation of one exercise variation, in the order they happened.
///
/// A log, not a set: the anti-decoreba window is "the last N exercises", and
/// the least-recently-used fallback needs to know *when* each root last played.
/// Both questions are answered by ordering on [sequence].
class RecentVariants extends Table {
  /// Monotonic counter assigned by SQLite (`AUTOINCREMENT`), so it is also the
  /// primary key.
  ///
  /// Recency is measured on this, not on [usedAt]: a wall clock can jump
  /// (NTP, timezone, a user changing the date) and the ordering of a history
  /// must not. [usedAt] is kept for diagnostics only.
  IntColumn get sequence => integer().autoIncrement()();

  /// Identifies the musical relation, stably and across app versions — e.g.
  /// `interval:M3:asc`, `scale:dorian:desc`. Built by
  /// `lib/exercicios/domain/exercise_variation.dart`; opaque here.
  TextColumn get relationKey => text().withLength(min: 1, max: 128)();

  /// The `audioSampleRef` token of the root the relation was played from
  /// (`sax_c4`, …).
  TextColumn get rootToken => text().withLength(min: 1, max: 64)();

  /// ISO 8601 UTC (AD convention: dates are stored as UTC text and converted
  /// only for presentation). Diagnostics only — see [sequence].
  TextColumn get usedAt => text()();
}

/// How many rows are kept. Comfortably above the 39-exercise window so pruning
/// can never truncate it, and low enough that the table cannot grow without
/// bound over years of practice.
const int recentVariantsRetained = 500;

/// Reads and writes [RecentVariants]. The only door into the table.
@DriftAccessor(tables: [RecentVariants])
class RecentVariantsDao extends DatabaseAccessor<AppDatabase>
    with _$RecentVariantsDaoMixin {
  RecentVariantsDao(super.attachedDatabase);

  /// The [limit] most recently recorded variations, newest first.
  Future<List<({int sequence, String relationKey, String rootToken})>>
  mostRecent(int limit) async {
    final rows =
        await (select(recentVariants)
              ..orderBy([(t) => OrderingTerm.desc(t.sequence)])
              ..limit(limit))
            .get();
    return [
      for (final row in rows)
        (
          sequence: row.sequence,
          relationKey: row.relationKey,
          rootToken: row.rootToken,
        ),
    ];
  }

  /// The latest [RecentVariants.sequence] of every (relation, root) pair the
  /// table still holds — one row per pair.
  ///
  /// Grouped in SQL rather than folded in Dart: the caller wants recency per
  /// pair across the whole retained history, and reading every row back to
  /// compute it would pull [recentVariantsRetained] rows to produce at most a
  /// few hundred.
  Future<List<({int sequence, String relationKey, String rootToken})>>
  lastUsePerRoot() async {
    final latest = recentVariants.sequence.max();
    final query = selectOnly(recentVariants)
      ..addColumns([
        recentVariants.relationKey,
        recentVariants.rootToken,
        latest,
      ])
      ..groupBy([recentVariants.relationKey, recentVariants.rootToken]);
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          sequence: row.read(latest)!,
          relationKey: row.read(recentVariants.relationKey)!,
          rootToken: row.read(recentVariants.rootToken)!,
        ),
    ];
  }

  /// The `used_at` of the most recent row, or `null` when the table is empty.
  ///
  /// Diagnostics only — and the one reader that lets a test prove the column
  /// really carries the injected clock in ISO 8601 UTC. Without a reader the
  /// column could hold local time, or anything, and every test would pass.
  Future<String?> latestUsedAt() async {
    final row =
        await (select(recentVariants)
              ..orderBy([(t) => OrderingTerm.desc(t.sequence)])
              ..limit(1))
            .getSingleOrNull();
    return row?.usedAt;
  }

  /// Appends one presentation and prunes anything older than the last
  /// [recentVariantsRetained] rows.
  ///
  /// Both statements run in one transaction so a reader never sees a pruned
  /// history without the row that justified pruning it.
  Future<void> record({
    required String relationKey,
    required String rootToken,
    required DateTime usedAt,
  }) => transaction(() async {
    await into(recentVariants).insert(
      RecentVariantsCompanion.insert(
        relationKey: relationKey,
        rootToken: rootToken,
        usedAt: usedAt.toUtc().toIso8601String(),
      ),
    );
    // Keep the newest `recentVariantsRetained`. Expressed as "everything at or
    // below the cut" rather than OFFSET so it is one indexed range delete.
    final cut =
        await (selectOnly(recentVariants)
              ..addColumns([recentVariants.sequence])
              ..orderBy([OrderingTerm.desc(recentVariants.sequence)])
              ..limit(1, offset: recentVariantsRetained))
            .map((row) => row.read(recentVariants.sequence))
            .getSingleOrNull();
    if (cut != null) {
      await (delete(
        recentVariants,
      )..where((t) => t.sequence.isSmallerOrEqualValue(cut))).go();
    }
  });

  /// How many rows the table holds. Diagnostics and tests only — nothing in
  /// the product reads it.
  Future<int> countAll() async {
    final count = recentVariants.sequence.count();
    final row = await (selectOnly(
      recentVariants,
    )..addColumns([count])).map((r) => r.read(count)).getSingle();
    return row ?? 0;
  }
}
