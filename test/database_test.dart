import 'package:catear/core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppDatabase opens at schema v2 and runs onCreate', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 2);

    // Forces the connection open -> beforeOpen + onCreate run without error.
    final row = await db
        .customSelect('SELECT sqlite_version() AS v')
        .getSingle();
    expect(row.data['v'], isNotNull);

    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);

    // `onCreate` (a fresh install) must produce the same table `onUpgrade`
    // produces for an existing one — see test/migration_test.dart for the
    // upgrade half.
    expect(await db.recentVariantsDao.countAll(), 0);
  });
}
