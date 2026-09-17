/// Local, device-scoped preferences as a key/value table (Story 1.10): the
/// third table of the CatEar database, at schema v4.
///
/// It lives under `core/database/` because Rule 2 of
/// `tool/check_module_boundaries.dart` keeps every Drift symbol inside `core/`.
/// Unlike `recent_variants` and `placements`, this table is *not* owned by a
/// feature module: a theme choice is a shell concern, so `lib/app/` is the only
/// writer, reaching it through `ThemePreferenceRepository` (`core/preferences/`)
/// — never through this file, and never through Drift directly.
///
/// Why key/value rather than a column per preference: every future shell
/// preference (Epic 3's playback volume, …) would otherwise cost a schema
/// version and a migration of its own. The trade is that the table is
/// untyped, so it is deliberately kept small: one repository per preference
/// owns its key, its encoding and what an unreadable value means.
///
/// The DAO returns plain strings rather than the Drift-generated row class:
/// generated symbols never leave `core/`.
library;

import 'package:drift/drift.dart';

import 'app_database.dart';

part 'preferences.g.dart';

/// One preference, as an opaque string keyed by an opaque string.
@DataClassName('PreferenceRow')
class Preferences extends Table {
  /// Identifies the preference (`theme_mode`, …). Owned by the repository that
  /// reads it; opaque here.
  TextColumn get key => text().withLength(min: 1, max: 64)();

  /// The stored value, encoded by that same repository. Never parsed here.
  TextColumn get value => text().withLength(max: 256)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Reads and writes [Preferences]. The only door into the table.
@DriftAccessor(tables: [Preferences])
class PreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$PreferencesDaoMixin {
  PreferencesDao(super.attachedDatabase);

  /// The value stored under [key], or `null` when nothing was ever written —
  /// which every caller reads as "the default applies".
  Future<String?> get(String key) async {
    final row = await (select(
      preferences,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Writes [value] under [key], replacing any earlier value.
  Future<void> put(String key, String value) => into(
    preferences,
  ).insertOnConflictUpdate(PreferencesCompanion.insert(key: key, value: value));
}
