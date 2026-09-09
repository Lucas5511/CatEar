@Tags(['migration'])
library;

import 'package:catear/core/core.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/migrations/schema.dart';

/// Migration-safety harness (test-design R2).
///
/// Story 1.1 ships `AppDatabase` empty (schema v1, no tables) but wires
/// `schemaVersion` + a `MigrationStrategy` from day one so later epics add
/// tables without wiping the user's local data. This suite is the guard that
/// keeps that promise:
///
///  * it verifies every shipped version is self-consistent today, and
///  * it fails loudly the moment `schemaVersion` is bumped without a matching
///    schema snapshot + verifier update.
///
/// Story 1.8 cashed the promise in: `recent_variants` arrives at v2 through
/// `onUpgrade`, and the 1 → 2 case below is the proof that an existing install
/// keeps its data across the step. When a later story adds a table:
///   1. `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/`
///   2. `dart run drift_dev schema generate drift_schemas/ test/generated/migrations/`
///   3. add a `migrateAndValidate(db, N)` case below, with the same
///      insert-at-N-1 → migrate → assert-rows-survive shape.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test(
    'generated schema snapshots cover every version up to the current one',
    () {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        GeneratedHelper.versions,
        contains(db.schemaVersion),
        reason:
            'AppDatabase.schemaVersion is ${db.schemaVersion} but there is no '
            'snapshot for it in drift_schemas/. Run:\n'
            '  dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/\n'
            '  dart run drift_dev schema generate drift_schemas/ test/generated/migrations/',
      );
      expect(
        GeneratedHelper.versions.last,
        db.schemaVersion,
        reason: 'the newest snapshot must match the live schema version',
      );
    },
  );

  test(
    'a fresh AppDatabase matches the schema the generated code expects',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Forces onCreate + beforeOpen, then compares sqlite_schema against what
      // drift generated from the table definitions. Fails if a table/column was
      // added without bumping schemaVersion and writing a migration.
      await db.validateDatabaseSchema();
    },
  );

  test('migrating a v1 database to v1 yields the expected schema', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection.executor);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 1);
  });

  test('v1 schema has no tables (the baseline Story 1.1 shipped)', () async {
    final schema = await verifier.schemaAt(1);
    expect(_userTables(schema.rawDatabase), isEmpty);
  });

  test('migrating a v1 database to v2 creates recent_variants', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection.executor);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 2);
  });

  test('rows written before the migration survive it', () async {
    // The reason `onUpgrade` exists at all (AR: "later epics add tables without
    // wiping the user's local data"). v1 has no table of its own to fill, so
    // the check is done on a table the app does not own: if the migration ever
    // becomes a `createAll()` on a wiped database — the shortcut that looks
    // harmless while the schema is nearly empty — this row disappears.
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      'CREATE TABLE legacy_rows (id INTEGER PRIMARY KEY, note TEXT NOT NULL)',
    );
    schema.rawDatabase.execute(
      "INSERT INTO legacy_rows (id, note) VALUES (1, 'written at v1')",
    );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get(); // forces the upgrade to run

    final survivors = await db
        .customSelect('SELECT note FROM legacy_rows')
        .get();
    expect(survivors.map((r) => r.data['note']), ['written at v1']);

    // …and the new table is usable straight after the upgrade, not just
    // present in `sqlite_schema`.
    await db.recentVariantsDao.record(
      relationKey: 'interval:M3:asc',
      rootToken: 'sax_c4',
      usedAt: DateTime.utc(2026, 9, 9),
    );
    expect(await db.recentVariantsDao.mostRecent(10), hasLength(1));
  });

  test('v2 schema holds exactly the recent_variants table', () async {
    final schema = await verifier.schemaAt(2);
    expect(_userTables(schema.rawDatabase), ['recent_variants']);
  });
}

/// The non-internal tables of [database], sorted.
List<String> _userTables(dynamic database) => (database.select(
  "SELECT name FROM sqlite_schema WHERE type = 'table' "
  "AND name NOT LIKE 'sqlite_%'",
) as Iterable).map<String>((row) => row['name'] as String).toList()..sort();
