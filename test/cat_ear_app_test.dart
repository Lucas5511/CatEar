import 'dart:async';

import 'package:catear/app/cat_ear_app.dart';
import 'package:catear/app/database_error_screen.dart';
import 'package:catear/app/home_shell.dart';
import 'package:catear/app/theme_mode_controller.dart';
import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/core/core.dart';
import 'package:catear/nivelamento/nivelamento.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "A level is already recorded" — what every pre-1.9 boot test assumed
/// implicitly. Overrides the Progressão's read provider, so the gate lands on
/// the shell without touching the (in-memory) database.
final levelled = placementProvider.overrideWith(
  (ref) async => Placement(
    stageId: 's-tercas',
    correctCount: 3,
    recordedAt: DateTime.utc(2026, 9, 15),
  ),
);

void main() {
  testWidgets('loading -> boot screen, then data -> HomeShell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          levelled,
          databaseProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const CatEarApp(),
      ),
    );

    // Still resolving.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(DatabaseErrorScreen), findsNothing);
  });

  testWidgets('database open, level still loading -> boot screen, then '
      'data -> HomeShell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placementProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return Placement(
              stageId: 's-tercas',
              correctCount: 3,
              recordedAt: DateTime.utc(2026, 9, 15),
            );
          }),
          databaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The database is open; the level is not read yet.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    expect(find.byType(NivelamentoScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('error -> DatabaseErrorScreen; retry -> HomeShell', (
    tester,
  ) async {
    var shouldFail = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          levelled,
          databaseProvider.overrideWith((ref) async {
            if (shouldFail) {
              throw StateError('boom');
            }
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DatabaseErrorScreen), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);

    // The retry button invalidates the provider; now let it succeed.
    shouldFail = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byType(DatabaseErrorScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('system dark platform brightness -> dark theme, no restart', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          levelled,
          databaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('picking "Escuro" in Settings switches brightness live', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          levelled,
          databaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Light by default (test platform brightness is light).
    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.dark,
    );
  });

  test('themeModeProvider defaults to system', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  // --- Story 1.9: the first-use gate, over the real Progressão port -----------

  /// The real app over a real in-memory database — nothing between the gate
  /// and the `placements` table is faked, only the audio.
  Future<void> pumpRealApp(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioServiceProvider.overrideWithValue(FakeAudioService()),
          databaseProvider.overrideWith((ref) async => db),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first boot (no level recorded) opens the levelling: no tab '
      'bar, no shell', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpRealApp(tester, db);

    expect(find.byType(NivelamentoScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(DatabaseErrorScreen), findsNothing);
    // The welcome, in the mascot's voice, before any card.
    expect(find.byType(MascotBubble), findsOneWidget);
  });

  testWidgets('boot with a level recorded through the port opens the shell', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Recorded the way the levelling records it: through the Progressão's
    // port, never through Drift.
    final seed = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    await seed
        .read(placementRepositoryProvider)
        .record(stageId: 's-quarta', correctCount: 3);
    seed.dispose();

    await pumpRealApp(tester, db);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(NivelamentoScreen), findsNothing);
    expect(find.text('Que bom ter você no CatEar!'), findsOneWidget);
  });

  testWidgets('a failed level read shows the error screen; retry recovers', (
    tester,
  ) async {
    var shouldFail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
          placementProvider.overrideWith((ref) async {
            if (shouldFail) throw StateError('read failed');
            return Placement(
              stageId: 's-tercas',
              correctCount: 3,
              recordedAt: DateTime.utc(2026, 9, 15),
            );
          }),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DatabaseErrorScreen), findsOneWidget);
    expect(find.byType(NivelamentoScreen), findsNothing);

    shouldFail = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byType(DatabaseErrorScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  // --- Story 1.10: the theme choice survives a restart ------------------------

  /// Records a level (so the gate lands on the shell) and a theme choice, both
  /// through the real ports, the way the app writes them.
  Future<void> seed(AppDatabase db, ThemeMode mode) async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    await container
        .read(placementRepositoryProvider)
        .record(stageId: 's-quarta', correctCount: 3);
    await container.read(themePreferenceRepositoryProvider).write(mode);
    container.dispose();
  }

  ThemeMode selectedThemeRadio(WidgetTester tester) => tester
      .widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>))
      .groupValue!;

  testWidgets('booting with "Escuro" stored: no frame of content is ever '
      'painted in the wrong theme', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seed(db, ThemeMode.dark);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioServiceProvider.overrideWithValue(FakeAudioService()),
          databaseProvider.overrideWith((ref) async => db),
        ],
        child: const CatEarApp(),
      ),
    );

    // Frame by frame through the whole boot: the moment the shell exists it is
    // already dark. A preference read that happened *after* the gate opened
    // would show one light frame here, which is the flash this test exists for.
    var sawContent = false;
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump();
      final shell = find.byType(HomeShell);
      if (shell.evaluate().isEmpty) continue;
      sawContent = true;
      expect(
        Theme.of(tester.element(shell)).brightness,
        Brightness.dark,
        reason: 'frame $frame painted the shell in the light theme',
      );
    }
    expect(sawContent, isTrue, reason: 'the boot never reached the shell');

    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(selectedThemeRadio(tester), ThemeMode.dark);
  });

  testWidgets('choosing "Escuro" survives a restart on the same database', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // A levelled install, no theme stored: the pre-1.10 state.
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    await container
        .read(placementRepositoryProvider)
        .record(stageId: 's-quarta', correctCount: 3);
    container.dispose();

    Future<void> boot() async {
      await tester.pumpWidget(
        ProviderScope(
          // A new scope: every provider is rebuilt from the database, which is
          // what reopening the app does.
          key: UniqueKey(),
          overrides: [
            audioServiceProvider.overrideWithValue(FakeAudioService()),
            databaseProvider.overrideWith((ref) async => db),
          ],
          child: const CatEarApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await boot();
    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    await boot();

    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(selectedThemeRadio(tester), ThemeMode.dark);
  });

  testWidgets('the gate holds the boot screen until the theme read lands, '
      'even when the database and the level are already there', (tester) async {
    // Both other reads resolve immediately, so nothing but the theme read can
    // hold the gate: delete the `storedTheme` branch of `CatEarApp` and this is
    // the test that goes red. The other boot tests cannot catch it — in them
    // the theme read happens to finish first.
    final theme = Completer<ThemeMode?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          levelled,
          databaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
          storedThemeModeProvider.overrideWith((ref) => theme.future),
        ],
        child: const CatEarApp(),
      ),
    );

    for (var frame = 0; frame < 6; frame++) {
      await tester.pump();
      expect(
        find.byType(HomeShell),
        findsNothing,
        reason: 'frame $frame showed content before the theme was known',
      );
      expect(find.byType(NivelamentoScreen), findsNothing);
    }
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    theme.complete(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('a mid-session database refresh keeps the chosen theme and the '
      'shell it was chosen from', (tester) async {
    // `DatabaseErrorScreen`'s retry invalidates `databaseProvider`, and every
    // provider below it recomputes — the theme preference included. Two things
    // must not happen: the choice reverting to what the provider held before
    // the write, and the whole shell being swapped for the boot screen while
    // the re-read is in flight.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Overridden, so invalidating the database cannot make the *level*
          // read reload: this test is about the theme branch of the gate.
          levelled,
          databaseProvider.overrideWith((ref) async => db),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.dark,
    );

    ProviderScope.containerOf(tester.element(find.byType(CatEarApp)))
        .invalidate(databaseProvider);

    for (var frame = 0; frame < 6; frame++) {
      await tester.pump();
      expect(
        find.byType(HomeShell),
        findsOneWidget,
        reason: 'frame $frame replaced the shell with the boot screen',
      );
      expect(
        Theme.of(tester.element(find.byType(HomeShell))).brightness,
        Brightness.dark,
        reason: 'frame $frame fell back to the light theme',
      );
    }
    await tester.pumpAndSettle();

    expect(selectedThemeRadio(tester), ThemeMode.dark);
    // Still on the tab the choice was made from — the shell was never rebuilt.
    expect(find.text('Seguir o sistema'), findsOneWidget);
  });

  testWidgets('a failed level read shows the error screen on the very next '
      'frames — no automatic retry keeping the boot screen up', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
          placementProvider.overrideWith(
            (ref) async => throw StateError('read failed'),
          ),
        ],
        child: const CatEarApp(),
      ),
    );
    // Past the database open, then two frames with no time advanced:
    // Riverpod's default retry would hold the read at loading for ~38 s.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(DatabaseErrorScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
