import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The CatEar local database.
///
/// Story 1.1 ships it empty: no tables yet (the first one arrives in Story 1.8).
/// [schemaVersion] and the [MigrationStrategy] are wired from day one so later
/// epics can add tables without wiping the user's local data.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // No migrations yet — schema v1 is the baseline.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
