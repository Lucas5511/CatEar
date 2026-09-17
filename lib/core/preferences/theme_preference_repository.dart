/// The stored theme choice, and the providers `lib/app/` reads it through.
///
/// A theme is a *shell* preference, not a feature's state, so this does not
/// live in a feature module the way `PlacementRepository` lives in Progressão
/// (AD-2, single-writer): `lib/app/` is the only reader and the only writer,
/// and `core/` is the one place both it and the database can meet without
/// breaking Rule 2 of `check_module_boundaries`.
///
/// Shape copied from `progressao/data/placement_repository_impl.dart`: the
/// implementation class is library-private, the database is reached as
/// `databaseProvider.future`, and no Drift-generated symbol escapes — the DAO
/// hands back a `String?`, which this file maps onto [ThemeMode].
library;

import 'dart:developer' as developer;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../database/preferences.dart';

part 'theme_preference_repository.g.dart';

/// The `preferences` key this repository owns. Nothing else may write it.
const String themeModePreferenceKey = 'theme_mode';

/// Reads and writes the learner's theme choice.
///
/// [read] answering `null` is not an error: it is "no choice stored", which the
/// app renders as [ThemeMode.system] — the same default it used before the
/// preference existed. A value that is not one of the three known tokens
/// (a downgrade, a hand-edited database) is treated the same way, logged.
abstract class ThemePreferenceRepository {
  /// The stored choice, or `null` when none is stored or the stored value is
  /// not recognised.
  Future<ThemeMode?> read();

  /// Stores [mode], replacing any earlier choice.
  Future<void> write(ThemeMode mode);
}

/// Provides the theme-preference port. `lib/app/` depends only on this.
///
/// Watches `databaseProvider.future` rather than its `AsyncValue`, like the
/// Progressão's ports: a failed open surfaces as a rejected future from
/// [ThemePreferenceRepository.read] / `.write`, which each caller degrades
/// around in its own way.
@riverpod
ThemePreferenceRepository themePreferenceRepository(Ref ref) =>
    _DriftThemePreferenceRepository(ref.watch(databaseProvider.future));

/// Belt and braces. What actually keeps the boot gate off Riverpod 3's default
/// retry (any thrown `Exception`, ~38 s of backoff with the state stuck on
/// `AsyncLoading`) is the `try/catch` in [storedThemeMode]: nothing escapes it,
/// so there is no error to retry. This stays so that a future edit which lets
/// an exception through does not quietly reintroduce a boot screen that spins
/// for half a minute.
Duration? _noRetry(int retryCount, Object error) => null;

/// The theme to boot with: the stored choice, or `null` for "follow the
/// system".
///
/// The boot gate in `CatEarApp` waits on this alongside the database so the
/// first frame with content is already in the right theme. It never surfaces an
/// error, because the `try/catch` below turns every failure into `null` plus a
/// log: a broken preference can therefore never hold the app on the boot screen
/// or send it to the database error screen (that screen belongs to
/// `databaseProvider`, which fails on its own when the database is really
/// unusable).
@Riverpod(retry: _noRetry)
Future<ThemeMode?> storedThemeMode(Ref ref) async {
  try {
    return await ref.watch(themePreferenceRepositoryProvider).read();
  } catch (error, stack) {
    developer.log(
      'Failed to read the stored theme preference; falling back to the system '
      'theme',
      name: 'catear.preferences',
      error: error,
      stackTrace: stack,
    );
    return null;
  }
}

class _DriftThemePreferenceRepository implements ThemePreferenceRepository {
  _DriftThemePreferenceRepository(this._database);

  final Future<AppDatabase> _database;

  Future<PreferencesDao> get _dao async => PreferencesDao(await _database);

  @override
  Future<ThemeMode?> read() async {
    final stored = await (await _dao).get(themeModePreferenceKey);
    if (stored == null) return null;
    final mode = _decode(stored);
    if (mode == null) {
      developer.log(
        'Ignoring unknown stored theme preference "$stored"; falling back to '
        'the system theme',
        name: 'catear.preferences',
      );
    }
    return mode;
  }

  @override
  Future<void> write(ThemeMode mode) async =>
      (await _dao).put(themeModePreferenceKey, _encode(mode));
}

/// The on-disk token for [mode]. Stable across app versions — the enum's
/// `index` is not, and its `name` would silently follow a Flutter rename.
String _encode(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

/// The inverse of [_encode], or `null` for anything it never wrote.
ThemeMode? _decode(String stored) => switch (stored) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  'system' => ThemeMode.system,
  _ => null,
};
