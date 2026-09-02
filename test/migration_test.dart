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
///  * it verifies v1 is self-consistent today, and
///  * it fails loudly the moment `schemaVersion` is bumped without a matching
///    schema snapshot + verifier update — which is the trip-wire Story 1.8
///    needs before it merges the first real table.
///
/// When Story 1.8 adds a table:
///   1. `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/`
///   2. `dart run drift_dev schema generate drift_schemas/ test/generated/migrations/`
///   3. add a `migrateAndValidate(db, 2)` case below (with data-integrity checks
///      via `verifier.schemaAt(1)` → insert rows → migrate → assert rows survive).
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

  test(
    'v1 schema has no tables (baseline — first table arrives in Story 1.8)',
    () async {
      final schema = await verifier.schemaAt(1);
      final tables = schema.rawDatabase
          .select(
            "SELECT name FROM sqlite_schema WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .map((row) => row['name'] as String)
          .toList();
      expect(tables, isEmpty);
    },
  );
}
