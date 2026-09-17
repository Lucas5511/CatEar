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
//   - app shell (Story 1.1 / 1.10): boot gate, 4-tab navigation, theme,
//     Android back, and the real build version in Settings → Sobre
//   - levelling (Story 1.9): first boot → the whole levelling over real audio
//     → summary → Home, and the second boot landing on Home off the real
//     `placements` row
//   - practice flow (Stories 1.4 / 1.5): the "Praticar" journey over the REAL
//     provider graph — the widget suite fakes `audioServiceProvider`, so this
//     is the only place the real `_JustAudioService` and its lifecycle are
//     exercised — once per motif contour: interval, chord and scale
//   - AudioService (Stories 1.3 / 1.3b): the shared contract suite run against
//     the real `_JustAudioService`, plus the provider-wiring case that only
//     exists on this side
//
// The database is overridden with an in-memory Drift database so the suite runs
// both headless and on-device; everything else is the real provider graph.

import 'package:catear/app/app_version.dart';
import 'package:catear/app/cat_ear_app.dart';
import 'package:catear/app/database_error_screen.dart';
import 'package:catear/app/home_shell.dart';
import 'package:catear/audio/audio.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/nivelamento/nivelamento.dart';
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

/// An in-memory database that already holds a starting level, recorded the
/// way the levelling records it — through the Progressão's port, over the real
/// provider graph — so a boot lands on the shell (Story 1.9). Every pre-1.9
/// journey assumed a levelled learner implicitly; this makes it explicit.
Future<AppDatabase> levelledDatabase() async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final seed = ProviderContainer(
    overrides: [databaseProvider.overrideWith((ref) async => db)],
  );
  await seed
      .read(placementRepositoryProvider)
      .record(stageId: 's-tercas', correctCount: 3);
  seed.dispose();
  return db;
}

/// Pumps the real app with an in-memory database.
///
/// [database] is the database the app opens; by default one that already
/// holds a starting level ([levelledDatabase]), so the boot lands on the
/// shell. Pass an empty one to land on the levelling, or the same one twice
/// to simulate a second boot.
///
/// [failFirst] makes the first open attempt throw so the retry path can be
/// exercised; the next attempt (after `ref.invalidate`) succeeds.
///
/// [practiceTypes] narrows the practice loop to one exercise type so a journey
/// can reach a chord or a scale card without answering its way there — the
/// real audio path stays untouched, only the selection changes.
///
/// [reporter] replaces the logging `SessionResultReporter` so a journey can
/// assert on what a session did — or did not — report (Story 1.7).
Future<void> pumpApp(
  WidgetTester tester, {
  AppDatabase? database,
  bool failFirst = false,
  Set<ExerciseType>? practiceTypes,
  SessionResultReporter? reporter,
}) async {
  var shouldFail = failFirst;
  final db = database ?? await levelledDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (practiceTypes != null)
          practiceExerciseTypesProvider.overrideWithValue(practiceTypes),
        if (reporter != null)
          sessionResultReporterProvider.overrideWithValue(reporter),
        databaseProvider.overrideWith((ref) async {
          if (shouldFail) {
            shouldFail = false;
            throw StateError('simulated database open failure');
          }
          return db;
        }),
      ],
      child: const CatEarApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Captures whatever a completed session reports, in place of the logging
/// reporter (Story 1.7).
class _RecordingReporter implements SessionResultReporter {
  final List<SessionResultReported> events = [];

  @override
  void report(SessionResultReported event) => events.add(event);
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

/// The label of the option the screen marked as the right answer.
///
/// After answering, the correct button is filled with the positive scaffold
/// token — that highlight is how the answer is legible from out here, since
/// the practice state lives behind a private `presentation/` provider.
String revealedAnswerLabel(WidgetTester tester) {
  final highlighted = find.byWidgetPredicate((w) {
    if (w is! FilledButton) return false;
    final bg = w.style?.backgroundColor?.resolve(const <WidgetState>{});
    return bg == CatColors.scaffoldConsonant ||
        bg == CatColors.scaffoldConsonantDark;
  });
  expect(
    highlighted,
    findsOneWidget,
    reason: 'answering must reveal the correct option',
  );
  return tester
      .widget<Text>(
        find.descendant(of: highlighted, matching: find.byType(Text)).first,
      )
      .data!;
}

/// Asserts the screen landed on a result that actually says something.
///
/// Correct: the celebratory line names the answer. Wrong: the mascot bubble is
/// there (it carries the app's only Fredoka text, which is what identifies it
/// from out here — its widget class is private to
/// `lib/exercicios/presentation/`) **and its sentence names the answer**. That
/// last part is FR-4 itself; matching the font alone would pass on an empty or
/// wrong sentence.
void expectExplainedResult(WidgetTester tester) {
  final answer = revealedAnswerLabel(tester);
  if (find.textContaining('Isso!').evaluate().isNotEmpty) {
    expect(find.textContaining('Isso! $answer'), findsOneWidget);
    return;
  }
  final bubble = find.byWidgetPredicate(
    (w) => w is Text && w.style?.fontFamily == 'Fredoka',
  );
  expect(
    bubble,
    findsOneWidget,
    reason: 'a wrong answer must get the mascot bubble, never a bare verdict',
  );
  expect(
    tester.widget<Text>(bubble).data,
    contains(answer),
    reason: 'FR-4: the explanation names the concept that was actually played',
  );
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

      // The only place `package_info_plus` actually talks to the platform: the
      // widget suite injects the value through `setMockInitialValues`, which
      // answers from a static before the channel is ever touched, so a plugin
      // that silently stopped resolving would ship with everything else green.
      // Read the tile's own `subtitle`, not "the last Text under it": a
      // `.last` on `find.byType(Text)` ranks over the WHOLE tree, and the
      // last Text in the running app is the `NavigationBar`'s "Ajustes"
      // label, which is no descendant of this tile — the finder then matches
      // nothing and dies as `Bad state: No element`. It only looked right
      // against a tree with the screen alone and no shell around it.
      final version =
          (tester
                      .widget<ListTile>(find.widgetWithText(ListTile, 'Versão'))
                      .subtitle!
                  as Text)
              .data!;
      expect(
        version,
        isNot(unknownAppVersion),
        reason: 'the build version degraded to "—" on a real device',
      );
      expect(
        version,
        matches(RegExp(r'^\S+ \(\S+\)$')),
        reason: 'expected "version (build)", got "$version"',
      );

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

      final db = await levelledDatabase();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWith((ref) async => db)],
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

      // Let the real AudioService sequence the interval motif
      // (450 + 450 + 900 ms) with slack for the platform player.
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

      expectExplainedResult(tester);

      // Story 1.8: the anti-decoreba history, over the REAL provider graph —
      // the practice notifier, the Progressão repository and a real Drift
      // database, none of them faked. The widget suite stubs the repository,
      // so a broken table, a broken migration or a broken provider wiring
      // would only ever show up here.
      // The shell is offstage behind the pushed exercise route, so the
      // container has to be read from the screen that is actually on top.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PracticeScreen)),
      );
      final recorded = await container
          .read(variantHistoryRepositoryProvider)
          .recent(limit: variantWindow);
      expect(
        recorded,
        isNotEmpty,
        reason: 'the exercise just played must be on the record',
      );
      expect(recorded.first.relationKey, startsWith('interval:'));
      expect(recorded.first.rootToken, startsWith('sax_'));
    });

    // Story 1.5 gave chord and scale their own contours, and they are a
    // different load on the real platform player than the interval's three
    // fires: a chord fires 5 times with three of them 260 ms apart, a scale
    // fires 8 times at 270 ms. Both exist only behind `FakeAudioService`
    // everywhere else, and the fake models "playSample was called", not "a
    // sound came out" — the same gap that let the auto-dispose regression
    // through. One journey per contour, in this file for the build-cost reason
    // at the top.
    Future<void> playsOneExerciseThrough(
      WidgetTester tester, {
      required ExerciseType type,
      required String prompt,
    }) async {
      await pumpApp(tester, practiceTypes: {type});

      await tester.tap(find.text('Praticar'));
      await tester.pumpAndSettle();
      expect(find.text(prompt), findsOneWidget);

      // The longest contour is the chord at 2380 ms; 6 s leaves slack for the
      // platform player on a cold emulator.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('O som não tocou'),
        findsNothing,
        reason: 'every fire of the $type motif must play on the real service',
      );

      final options = find.byType(FilledButton);
      expect(options, findsWidgets);
      await tester.tap(options.first);
      await tester.pumpAndSettle();

      expectExplainedResult(tester);
    }

    testWidgets('Praticar plays a real chord motif (block, arpeggio, block)', (
      tester,
    ) async {
      await playsOneExerciseThrough(
        tester,
        type: ExerciseType.chord,
        prompt: 'Que acorde é este?',
      );
    });

    testWidgets('Praticar plays a real scale motif (all 8 notes)', (
      tester,
    ) async {
      await playsOneExerciseThrough(
        tester,
        type: ExerciseType.scale,
        prompt: 'Que escala é esta?',
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

    // Story 1.7: abandonment over the real provider graph. The widget suite
    // covers the rule; this covers the wiring — that the reporter the app
    // actually resolves is never reached by a session the learner walked out
    // of, attempts already on the books.
    testWidgets('leaving after answering reports no session', (tester) async {
      final reporter = _RecordingReporter();
      await pumpApp(tester, reporter: reporter);

      await tester.tap(find.text('Praticar'));
      await tester.pumpAndSettle();

      // Play the motif for real, then answer one exercise.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expectExplainedResult(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(HomeShell), findsOneWidget);
      expect(
        reporter.events,
        isEmpty,
        reason: 'an abandoned session reports nothing, however far it got',
      );
    });
  });

  // Story 1.9: the levelling over the REAL provider graph — real audio for
  // all seven cards, the real Progressão port over a real Drift database, and
  // the boot gate reading it back. The widget suite fakes the audio and the
  // port; this is the only place the first-use journey runs end to end.
  group('levelling (Story 1.9)', () {
    /// Answers the card on screen with its first option and moves on: waits
    /// out the celebration on a right answer, taps "Continuar" on a wrong one.
    Future<void> answerCurrentCard(WidgetTester tester) async {
      // Let the real AudioService sequence the interval motif
      // (450 + 450 + 900 ms) with slack for the platform player.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Que intervalo é este?'), findsOneWidget);
      expect(
        find.textContaining('O som não tocou'),
        findsNothing,
        reason: 'the real AudioService must stay alive across the cards',
      );
      final options = find.byType(FilledButton);
      expect(options, findsWidgets);
      await tester.tap(options.first);
      await tester.pumpAndSettle();
      expectExplainedResult(tester);
      if (find.text('Continuar').evaluate().isNotEmpty &&
          find.textContaining('Isso!').evaluate().isEmpty) {
        await tester.tap(find.text('Continuar'));
      }
      // Either the auto-advance (flourish + 700 ms) or the tap has moved on.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'first boot: the levelling end to end, then Home; second boot: Home',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        await pumpApp(tester, database: db);

        // First use: the levelling fills the screen — no shell, no tab bar.
        expect(find.byType(NivelamentoScreen), findsOneWidget);
        expect(find.byType(HomeShell), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(MascotBubble), findsOneWidget);

        await tester.tap(find.text('Vamos lá'));
        await tester.pumpAndSettle();

        for (var i = 0; i < placementSequence.length; i++) {
          await answerCurrentCard(tester);
        }

        // The summary: the mascot, a named level, one CTA.
        expect(find.byType(ExerciseCardFlow), findsNothing);
        expect(find.byType(MascotBubble), findsOneWidget);
        expect(find.text('Ir para a Home'), findsOneWidget);
        final placed = await ProviderScope.containerOf(
          tester.element(find.byType(NivelamentoScreen)),
        ).read(placementRepositoryProvider).current();
        expect(placed, isNotNull, reason: 'the level is on the record');
        expect(find.text(stageNameFor(placed!.stageId)), findsOneWidget);
        expect(placed.correctCount, inInclusiveRange(0, 7));

        await tester.tap(find.text('Ir para a Home'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeShell), findsOneWidget);
        expect(find.text('Que bom ter você no CatEar!'), findsOneWidget);
        expect(navBar(tester).selectedIndex, 0);

        // Back does not return to the levelling: the gate swapped it out in
        // place, so there is no route beneath the shell to pop to. Asserted
        // on the Navigator rather than by firing a back event — on the root
        // route, with nothing to pop, `handlePopRoute` falls through to
        // `SystemNavigator.pop()`, which finishes the Android activity, and
        // every later platform-channel call in this run (the real
        // `AudioPlayer` of the next group) then hangs until the job's
        // timeout. The two `handlePopRoute` calls above run on a deep tab or
        // a pushed route, where something is there to consume the event.
        expect(find.byType(NivelamentoScreen), findsNothing);
        expect(
          Navigator.of(tester.element(find.byType(HomeShell))).canPop(),
          isFalse,
          reason: 'nothing beneath the shell — the levelling was not pushed',
        );

        // Second boot over the same database: straight to Home.
        await pumpApp(tester, database: db);
        expect(find.byType(HomeShell), findsOneWidget);
        expect(find.byType(NivelamentoScreen), findsNothing);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  // The full AudioService contract, against the real service. Anything that is
  // true of both implementations lives in the shared file, not here.
  runAudioServiceContract(
    target: 'real _JustAudioService',
    build: () => realService().service,
    timeout: _playTimeout,
  );

  group('real AudioService — pre-rendered triads (Story 1.4b)', () {
    // The 8 triad blocks are the only samples that are not single notes, and
    // they were mixed offline rather than sourced. Playing each one through the
    // real service proves the mixed file is bundled and decodable on-device —
    // the `gates` job only ever sees it through `rootBundle`.
    const triads = <String>[
      'sax_maj_c4',
      'sax_min_c4',
      'sax_dim_c4',
      'sax_aug_c4',
      'sax_maj_d4',
      'sax_min_d4',
      'sax_dim_d4',
      'sax_aug_d4',
    ];

    testWidgets('every triad token plays to completion', (tester) async {
      final (container: _, :service) = realService();

      for (final ref in triads) {
        await service.playSample(ref).timeout(_playTimeout);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

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
