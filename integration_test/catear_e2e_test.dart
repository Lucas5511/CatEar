// End-to-end journeys for CatEar, on a real device/emulator.
//
// ONE file on purpose. `flutter test integration_test` compiles and installs a
// separate APK per test file (~8 min of Gradle each on a 2-core CI runner), so
// every extra file is another full build and another window for the emulator
// to be starved or the runner to be reclaimed — which is exactly how the
// `e2e-android` job has been failing. Add new journeys as a `group` here, not
// as a new file.
//
// Covered:
//   - app shell (Story 1.1): boot gate, 4-tab navigation, theme, Android back
//   - practice flow (Story 1.4): the "Praticar" journey over the REAL provider
//     graph — the widget suite fakes `audioServiceProvider`, so this is the
//     only place the real `_JustAudioService` and its lifecycle are exercised
//   - AudioService (Stories 1.3 / 1.3b): the shared contract suite run against
//     the real `_JustAudioService`, plus the provider-wiring case that only
//     exists on this side
//
// The database is overridden with an in-memory Drift database so the suite runs
// both headless and on-device; everything else is the real provider graph.

import 'package:catear/app/cat_ear_app.dart';
import 'package:catear/app/database_error_screen.dart';
import 'package:catear/app/home_shell.dart';
import 'package:catear/audio/audio.dart';
import 'package:catear/core/core.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Both suites run the SAME AudioService contract: this one against the real
// `_JustAudioService`, `test/audio_service_test.dart` against the fake. Keeping
// them in one file is the point — the fake used to be stronger than the real
// service (it serialized overlapping calls; the real one did not), so the unit
// suite was green while the exercise played no audio at all.
import '../test/support/audio_service_contract.dart';

// ---------------------------------------------------------------- app shell

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

// ------------------------------------------------------------ audio service

/// Hard ceiling on any single real playback call. A 2.5 s sample completes in
/// ~2.5 s; if the emulator's audio sink never signals completion the job should
/// fail fast here, not hang until the CI timeout.
const _playTimeout = Duration(seconds: 15);

/// A container whose `audioServiceProvider` is the real (unoverridden) service,
/// kept alive by a live subscription so the auto-dispose provider is not torn
/// down before the test drives it.
///
/// Registers tear-downs for both the subscription and the container. The
/// container tear-down is guarded so a test that disposes the container itself
/// (or an `expect` that throws before it does) never leaks the underlying
/// `AudioPlayer` platform resource.
({ProviderContainer container, AudioService service}) realService() {
  final container = ProviderContainer();
  final sub = container.listen(
    audioServiceProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(() {
    try {
      sub.close();
    } catch (_) {
      // Container already disposed — the subscription went with it.
    }
  });
  addTearDown(() {
    try {
      container.dispose();
    } on StateError {
      // A test disposed the container on purpose; a second call is a no-op.
    }
  });
  return (container: container, service: sub.read());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('app shell and practice flow', () {
    testWidgets('first launch lands on the Home tab in the light theme', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('Que bom ter você no CatEar!'), findsOneWidget);
      expect(navBar(tester).selectedIndex, 0);
      expect(activeBrightness(tester), Brightness.light);
    });

    testWidgets('user walks through every tab and back to Home', (
      tester,
    ) async {
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

    testWidgets('system dark mode is honoured without a restart', (
      tester,
    ) async {
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
  });

  // The full AudioService contract, against the real service. Anything that is
  // true of both implementations lives in the shared file, not here.
  runAudioServiceContract(
    target: 'real _JustAudioService',
    build: () => realService().service,
    timeout: _playTimeout,
  );

  group('real AudioService — provider wiring', () {
    // The one case the fake cannot answer: `audioServiceProvider` is
    // auto-dispose and wires `ref.onDispose(service.dispose)`, so tearing the
    // container down must release the platform `AudioPlayer`. (The mirror of
    // this on the widget side — the screen holding the provider open for its
    // lifetime — is `test/exercicios/audio_lifecycle_test.dart`.)
    testWidgets(
      'disposing the container disposes the service, without throwing',
      (tester) async {
        final (:container, :service) = realService();

        await service.playSample('sax_g4').timeout(_playTimeout);

        // The async work of `_JustAudioService.dispose()` runs after this
        // returns; the post-dispose `StateError` assertions below are what
        // prove it ran.
        container.dispose();

        await expectLater(
          service.playSample('sax_c4'),
          throwsA(isA<StateError>()),
        );
        await expectLater(service.stop(), throwsA(isA<StateError>()));
      },
    );
  });
}
