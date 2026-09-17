import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';

/// Holds the user's theme choice (light / dark / follow system).
///
/// Since Story 1.10 the choice is persisted: [build] starts from whatever
/// `core/`'s [ThemePreferenceRepository] has stored (nothing stored, or
/// anything unreadable, means [ThemeMode.system] — the pre-1.10 default), and
/// [set] writes the new choice back.
///
/// It stays a synchronous [Notifier] rather than an `AsyncNotifier` on purpose:
/// `MaterialApp.themeMode` needs a `ThemeMode` on every frame, including the
/// boot frames before the database is open. Watching [storedThemeModeProvider]
/// gives that — `system` while the read is in flight, the stored value the
/// moment it lands — and `CatEarApp` waits on the very same provider before it
/// shows any *content*, so the first frame a learner actually sees is already
/// in the right theme.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ref.watch(storedThemeModeProvider).value ?? ThemeMode.system;

  /// Applies [mode] now and stores it.
  ///
  /// The state changes in this same frame, before the write is even issued: a
  /// database round-trip must never sit between a tap and the theme changing,
  /// and a write that fails is a preference that will not survive the restart —
  /// not a reason to refuse the choice. Failures are logged and swallowed, and
  /// the stored value is left alone — the in-memory choice stands for this
  /// session and the next boot simply reads whatever did survive.
  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await ref.read(themePreferenceRepositoryProvider).write(mode);
      // [build] re-derives `state` from [storedThemeModeProvider], and anything
      // that recomputes this notifier (the database error screen's retry
      // invalidates `databaseProvider`, which every provider below it watches)
      // would otherwise hand the learner back the value that provider was
      // holding from before this write — silently undoing the choice.
      ref.invalidate(storedThemeModeProvider);
    } catch (error, stack) {
      developer.log(
        'Failed to store the theme preference; it applies now but will not '
        'survive a restart',
        name: 'catear.preferences',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
