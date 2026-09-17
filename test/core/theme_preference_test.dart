import 'package:catear/core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Story 1.10 — the storage half of the theme choice.
///
/// Drives the real `themePreferenceRepositoryProvider` against a real in-memory
/// Drift database, through the `core` barrel only. The DAO is reached solely to
/// plant a value the repository never wrote (the "unknown token" row of the
/// matrix); nothing here names a Drift-generated symbol.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A container whose `databaseProvider` is an in-memory database, handed back
  /// alongside that database — the tests that plant or count rows need both,
  /// and a shared field assigned inside the override would be unset in the
  /// failing case below.
  ({ProviderContainer container, AppDatabase db}) containerWith() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);
    return (container: container, db: db);
  }

  /// The "database unavailable" row of the matrix: the open itself throws.
  ProviderContainer failingContainer() {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith(
          (ref) async => throw StateError('simulated open failure'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  ThemePreferenceRepository repoOf(ProviderContainer c) =>
      c.read(themePreferenceRepositoryProvider);

  test(
    'a fresh install has no stored theme, and that is not an error',
    () async {
      expect(await repoOf(containerWith().container).read(), isNull);
    },
  );

  test(
    'every mode round-trips, and a second write replaces the first',
    () async {
      final (:container, :db) = containerWith();
      final repo = repoOf(container);

      for (final mode in ThemeMode.values) {
        await repo.write(mode);
        expect(await repo.read(), mode);
      }

      // One preference, one row — `put` upserts rather than appending.
      final rows = await db
          .customSelect('SELECT COUNT(*) AS c FROM preferences')
          .getSingle();
      expect(rows.data['c'], 1);
    },
  );

  test('the stored token is stable text, not the enum index', () async {
    // The value on disk outlives the app version that wrote it: an index would
    // silently change meaning if `ThemeMode`'s order ever did.
    final (:container, :db) = containerWith();
    await repoOf(container).write(ThemeMode.dark);

    expect(await db.preferencesDao.get(_themeModeKey), 'dark');
  });

  test(
    'an unknown stored value reads as null (-> follow the system)',
    () async {
      final (:container, :db) = containerWith();
      final repo = repoOf(container);
      // Plant what a downgrade or a hand-edited database would leave behind.
      await repo.write(ThemeMode.dark);
      await db.preferencesDao.put(_themeModeKey, 'solarized');

      expect(await repo.read(), isNull);
    },
  );

  test('an unavailable database rejects both reads and writes', () async {
    final repo = repoOf(failingContainer());

    await expectLater(repo.read(), throwsA(isA<StateError>()));
    await expectLater(repo.write(ThemeMode.dark), throwsA(isA<StateError>()));
  });

  test('storedThemeMode surfaces the stored choice', () async {
    final container = containerWith().container;
    await repoOf(container).write(ThemeMode.light);
    // The repository is rebuilt on a fresh read, as it would be on a new boot.
    container.invalidate(storedThemeModeProvider);

    expect(
      await container.read(storedThemeModeProvider.future),
      ThemeMode.light,
    );
  });

  test('storedThemeMode degrades to null when the database is unusable — a '
      'broken preference never blocks the boot', () async {
    final container = failingContainer();

    expect(await container.read(storedThemeModeProvider.future), isNull);
    expect(container.read(storedThemeModeProvider).hasError, isFalse);
  });
}

/// The `preferences` key the theme repository owns. A local copy: the key is
/// `core/`'s business, not part of its public surface, and the round-trip tests
/// in `test/core/theme_preference_test.dart` are what prove it is this one.
const String _themeModeKey = 'theme_mode';
