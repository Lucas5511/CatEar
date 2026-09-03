// End-to-end tests for the CatEar app shell (Story 1.1).
//
// These drive the real [CatEarApp] widget tree — boot gate, 4-tab navigation,
// theme switching and the Android back button — as linear user journeys.
//
// The database is overridden with an in-memory Drift database so the suite runs
// both headless (`flutter test integration_test/app_shell_test.dart`) and
// on-device (`flutter test integration_test` / `flutter drive`). On-device runs
// additionally exercise the real platform channels (path_provider, sqlite3).

import 'package:catear/app/cat_ear_app.dart';
import 'package:catear/app/database_error_screen.dart';
import 'package:catear/app/home_shell.dart';
import 'package:catear/core/core.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Pumps the real app with an in-memory database.
///
/// [failFirst] makes the first open attempt throw so the retry path can be
/// exercised; the next attempt (after `ref.invalidate`) succeeds.
Future<void> pumpApp(WidgetTester tester, {bool failFirst = false}) async {
  var shouldFail = failFirst;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) async {
          if (shouldFail) {
            shouldFail = false;
            throw StateError('simulated database open failure');
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
}

NavigationBar navBar(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

Brightness activeBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(HomeShell))).brightness;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch lands on the Home tab in the light theme', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Que bom ter você no CatEar!'), findsOneWidget);
    expect(navBar(tester).selectedIndex, 0);
    expect(activeBrightness(tester), Brightness.light);
  });

  testWidgets('user walks through every tab and back to Home', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Trilha'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillTreePlaceholderScreen), findsOneWidget);
    expect(navBar(tester).selectedIndex, 1);

    await tester.tap(find.text('Progresso'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressPlaceholderScreen), findsOneWidget);
    expect(navBar(tester).selectedIndex, 2);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Seguir o sistema'), findsOneWidget);
    expect(navBar(tester).selectedIndex, 3);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Que bom ter você no CatEar!'), findsOneWidget);
    expect(navBar(tester).selectedIndex, 0);
  });

  testWidgets('no swipe navigation and no Drawer', (tester) async {
    await pumpApp(tester);

    expect(find.byType(PageView), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(IndexedStack), findsOneWidget);
  });

  testWidgets('Android back button on a deep tab returns to Home, not exit', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(navBar(tester).selectedIndex, 3);

    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(popped, isTrue, reason: 'the shell consumed the back event');
    expect(navBar(tester).selectedIndex, 0);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('changing the theme in Settings applies immediately', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(activeBrightness(tester), Brightness.light);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(activeBrightness(tester), Brightness.dark);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(activeBrightness(tester), Brightness.light);
  });

  testWidgets('system dark mode is honoured without a restart', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(tester);

    // Default theme mode is "follow system".
    expect(activeBrightness(tester), Brightness.dark);
  });

  testWidgets('database failure shows the error screen, retry recovers', (
    tester,
  ) async {
    await pumpApp(tester, failFirst: true);

    expect(find.byType(DatabaseErrorScreen), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byType(DatabaseErrorScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Que bom ter você no CatEar!'), findsOneWidget);
  });

  testWidgets('shell survives extreme text scaling without overflow', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: CatEarApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final tab in ['Trilha', 'Progresso', 'Ajustes', 'Home']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
    }

    final overflow = errors.where(
      (e) => e.exceptionAsString().contains('overflowed'),
    );
    expect(overflow, isEmpty, reason: overflow.map((e) => '$e').join('\n'));
  });

  // --- Story 1.4: the practice flow over the REAL provider graph ------------
  //
  // Every widget test of the exercise screen overrides `audioServiceProvider`
  // with a `FakeAudioService`, so none of them exercises the real
  // `_JustAudioService` or its auto-dispose lifecycle. That gap let a shipped
  // regression through: the screen only `ref.read` the auto-dispose provider,
  // so the real service was torn down before the first motif and every
  // `playSample` threw `StateError`. This journey is the guard — it lives in
  // this file (not a new one) because `flutter test integration_test` runs a
  // full Gradle build per file, and a third build starves the CI emulator.

  testWidgets('Praticar plays a real interval motif and takes an answer', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Praticar'));
    await tester.pumpAndSettle();
    expect(find.text('Que intervalo é este?'), findsOneWidget);
    expect(find.text('Ouvir de novo'), findsOneWidget);

    // Let the real AudioService sequence the motif (450 + 450 + 900 ms) with
    // slack for the platform player.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // The whole point: with the real (auto-dispose) provider the playback must
    // succeed. A torn-down service surfaces the audio-error banner instead.
    expect(
      find.textContaining('O som não tocou'),
      findsNothing,
      reason: 'the real AudioService must stay alive for the screen lifetime',
    );

    // The options are live and answering produces a result line.
    final options = find.byType(FilledButton);
    expect(options, findsWidgets);
    await tester.tap(options.first);
    await tester.pumpAndSettle();

    final resultLine =
        find.textContaining('Isso!').evaluate().isNotEmpty ||
        find.textContaining('Não foi dessa vez').evaluate().isNotEmpty;
    expect(
      resultLine,
      isTrue,
      reason: 'answering must land on a correct or incorrect result line',
    );
  });

  testWidgets('leaving the exercise mid-flow returns to Home cleanly', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Praticar'));
    await tester.pumpAndSettle();
    expect(find.text('Que intervalo é este?'), findsOneWidget);

    // Pop while the motif is still sequencing — teardown must not throw.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Que bom ter você no CatEar!'), findsOneWidget);
  });
}
