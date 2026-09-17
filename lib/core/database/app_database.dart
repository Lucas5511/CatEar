import 'package:drift/drift.dart';

import 'placements.dart';
import 'preferences.dart';
import 'recent_variants.dart';

part 'app_database.g.dart';

/// The CatEar local database.
///
/// Story 1.1 shipped it empty (schema v1, no tables) with [schemaVersion] and a
/// [MigrationStrategy] wired from day one, so later epics could add tables
/// without wiping the user's local data. Story 1.8 is the first to cash that in:
/// [RecentVariants] arrives at schema v2 through [MigrationStrategy.onUpgrade],
/// and `test/migration_test.dart` proves a v1 database keeps its rows. Story
/// 1.9 adds [Placements] at v3 the same way, and Story 1.10 [Preferences] at
/// v4.
@DriftDatabase(
  tables: [RecentVariants, Placements, Preferences],
  daos: [RecentVariantsDao, PlacementsDao, PreferencesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v1 -> v2 (Story 1.8): the recent-variation history. Additive — an
      // existing install keeps every row it had (it had none, v1 having no
      // tables, but the shape of the step is what the next one copies).
      if (from < 2) {
        await m.createTable(recentVariants);
      }
      // v2 -> v3 (Story 1.9): the starting level. Additive again — every
      // `recent_variants` row an install has is kept.
      if (from < 3) {
        await m.createTable(placements);
      }
      // v3 -> v4 (Story 1.10): the key/value preferences table, so the theme
      // choice survives a restart. Additive again — `recent_variants` and
      // `placements` keep every row, and the new table simply starts empty
      // (no preference stored == the defaults the app already used).
      if (from < 4) {
        await m.createTable(preferences);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
