import 'package:catear/core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppDatabase opens at schema v4 and runs onCreate', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, 4);

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
    expect(await db.placementsDao.countAll(), 0);
    expect(await db.preferencesDao.get(_themeModeKey), isNull);
  });
}

/// The `preferences` key the theme repository owns. A local copy: the key is
/// `core/`'s business, not part of its public surface, and the round-trip tests
/// in `test/core/theme_preference_test.dart` are what prove it is this one.
const String _themeModeKey = 'theme_mode';
