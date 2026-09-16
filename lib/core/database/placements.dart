/// The starting level the levelling assigns (Story 1.9): the second table of
/// the CatEar database, at schema v3.
///
/// It lives under `core/database/` because Rule 2 of
/// `tool/check_module_boundaries.dart` keeps every Drift symbol inside `core/`.
/// The *owner* of the data is the Progressão module (AD-2, single-writer): it
/// reaches this DAO through the `core.dart` barrel, maps the row onto its own
/// pure `Placement`, and is the only module that writes it. The levelling
/// module writes through that port, never through this file.
///
/// The DAO returns records rather than the Drift-generated row class:
/// `Placement` (the generated data class would have been called that too) is a
/// generated symbol, and generated symbols never leave `core/`.
library;

import 'package:drift/drift.dart';

import 'app_database.dart';

part 'placements.g.dart';

/// The learner's starting level, as the levelling assigned it.
///
/// Holds at most one row: [PlacementsDao.record] replaces whatever was there.
@DataClassName('PlacementRow')
class Placements extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The catalog `stageId` the learner starts from (`s-tercas`, …). Text, not a
  /// foreign key: the catalog is a JSON asset, not a table.
  TextColumn get stageId => text().withLength(min: 1, max: 64)();

  /// How many of the levelling's exercises were answered correctly. Diagnostics
  /// for Epic 2's calibration; never shown to a learner who scored zero.
  IntColumn get correctCount => integer()();

  /// ISO 8601 UTC (AD convention: dates are stored as UTC text and converted
  /// only for presentation).
  TextColumn get recordedAt => text()();
}

/// Reads and writes [Placements]. The only door into the table.
@DriftAccessor(tables: [Placements])
class PlacementsDao extends DatabaseAccessor<AppDatabase>
    with _$PlacementsDaoMixin {
  PlacementsDao(super.attachedDatabase);

  /// The most recently recorded placement, or `null` when none was recorded —
  /// which is what "first use" means to the boot gate.
  Future<({String stageId, int correctCount, String recordedAt})?>
  current() async {
    final row =
        await (select(placements)
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return (
      stageId: row.stageId,
      correctCount: row.correctCount,
      recordedAt: row.recordedAt,
    );
  }

  /// Records the placement, replacing any earlier one, so the table holds
  /// exactly one row afterwards. Both statements run in one transaction so a
  /// reader never sees an empty table between them.
  Future<void> record({
    required String stageId,
    required int correctCount,
    required DateTime recordedAt,
  }) => transaction(() async {
    await delete(placements).go();
    await into(placements).insert(
      PlacementsCompanion.insert(
        stageId: stageId,
        correctCount: correctCount,
        recordedAt: recordedAt.toUtc().toIso8601String(),
      ),
    );
  });

  /// How many rows the table holds. Diagnostics and tests only.
  Future<int> countAll() async {
    final count = placements.id.count();
    final row = await (selectOnly(
      placements,
    )..addColumns([count])).map((r) => r.read(count)).getSingle();
    return row ?? 0;
  }
}
