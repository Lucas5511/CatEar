import 'dart:io';

import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/curriculo/data/catalog_asset_bundle.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/exercicios/presentation/exercise_card.dart';
import 'package:catear/exercicios/presentation/interval_exercise_screen.dart';
import 'package:catear/exercicios/presentation/phrase_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository whose `load()` always fails — for the catalog-error path.
class _FailingRepo implements CurriculoRepository {
  _FailingRepo(this.error);

  final Object error;

  @override
  Future<Curriculum> load() async => throw error;
}

/// Feeds the real `catalog_v1.json` from disk as an in-memory bundle so the
/// load resolves on a microtask (no real file I/O under the fake clock).
class _RealCatalogBundle extends CachingAssetBundle {
  _RealCatalogBundle()
    : _bytes = Uint8List.fromList(
        File('assets/curriculum/catalog_v1.json').readAsBytesSync(),
      );

  final Uint8List _bytes;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(_bytes);
}

/// Captures what a completed session reports, in place of the logging
/// reporter. The seam Epic 2 will take over is the same one a test uses here —
/// there is no global bus to spy on (AR-4).
class _RecordingReporter implements SessionResultReporter {
  final List<SessionResultReported> events = [];

  @override
  void report(SessionResultReported event) => events.add(event);
}

/// Stands in for the DB-backed reporter Epic 2 will install, on the day the
/// write fails.
class _ThrowingReporter implements SessionResultReporter {
  int calls = 0;

  @override
  void report(SessionResultReported event) {
    calls++;
    throw StateError('ingestion is down');
  }
}

ProviderContainer _container({
  FakeAudioService? audio,
  Object? catalogError,
  Set<ExerciseType>? types,
  PracticeTimings? timings,
  SessionResultReporter? reporter,
}) {
  return ProviderContainer(
    overrides: [
      audioServiceProvider.overrideWithValue(audio ?? FakeAudioService()),
      // Story 1.7: where a completed session goes. Left as the logging default
      // unless a test cares, so the emission path is exercised either way.
      if (reporter != null)
        sessionResultReporterProvider.overrideWithValue(reporter),
      // The product loop holds all three tappable types since Story 1.5.
      // Narrowing the type set is how a test isolates one of them in this
      // exact widget tree, without any product change.
      if (types != null) practiceExerciseTypesProvider.overrideWithValue(types),
      // The screen's non-motif timings, injectable rather than matched by hand.
      if (timings != null) practiceTimingsProvider.overrideWithValue(timings),
      if (catalogError != null)
        curriculoRepositoryProvider.overrideWithValue(
          _FailingRepo(catalogError),
        )
      else
        catalogAssetBundleProvider.overrideWithValue(_RealCatalogBundle()),
    ],
  );
}

/// [home] is swappable so a test can leave the exercise screen the way the app
/// does — popping what is on screen while the `ProviderScope` stays mounted.
/// Unmounting the scope instead unbinds the container's vsync, and any
/// auto-dispose it schedules is never flushed.
Widget _app(
  ProviderContainer container, {
  Brightness brightness = Brightness.light,
  Widget home = const IntervalExerciseScreen(),
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(theme: appTheme(brightness), home: home),
);

/// Pumps past the catalog load and exactly the first motif playback, so that
/// afterwards the fake clock and the reaction-time anchor (`_enabledAt`) are
/// both at the same instant — every ms pumped after this is reaction time.
///
/// The motif length is per type since Story 1.5 — 1800 ms for an interval,
/// 2380 ms for a chord, 2340 ms for a scale — so it is read off the question
/// under test instead of being a constant this file keeps in sync by hand. The
/// previous global `1800 ms` is exactly the hard-coded coupling the deferred
/// "no injection seam for the timings" item named.
Future<void> _settleFirstMotif(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pump(); // catalog future resolves
  await tester.pump(); // _ActiveExerciseView mounts, motif scheduled
  await tester.pump(); // post-frame callback fires the motif
  await tester.pump(_state(container).current.motifTotal); // motif gaps elapse
  await tester.pump();
}

PracticeState _state(ProviderContainer c) =>
    c.read(intervalPracticeProvider).value!;

/// Answers the current card correctly and asks the loop to move on, through the
/// notifier — the same calls the card makes, without waiting out a motif and a
/// flourish per exercise. Used where the subject is the *session* around the
/// cards rather than one card's behaviour.
void _answerAndAdvance(ProviderContainer c) {
  final notifier = c.read(intervalPracticeProvider.notifier);
  notifier.answer(_state(c).answer, 100);
  notifier.advance();
}

/// Walks [count] exercises the same way.
void _answerMany(ProviderContainer c, int count) {
  for (var i = 0; i < count; i++) {
    _answerAndAdvance(c);
  }
}

/// The offer view's two buttons — equal by construction, so the test names
/// them the way a learner reads them.
Finder _continuePracticing() => find.text('Continuar praticando');
Finder _finishForToday() => find.text('Encerrar por hoje');

/// The one private view that renders every exercise. Finding the *same* widget
/// type for interval, chord and scale is what "no per-type widget" means at
/// runtime; `check_module_boundaries` Rule 6 is the static half.
Finder _activeView() => find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_ActiveExerciseView',
);

Finder _fredoka() => find.byWidgetPredicate(
  (w) => w is Text && w.style?.fontFamily == 'Fredoka',
);

/// The practice screen under the maximum accessibility text size.
Widget _scaledApp(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: appTheme(Brightness.light),
    home: const MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(2.2)),
      child: IntervalExerciseScreen(),
    ),
  ),
);

/// The [ErrorType] the taxonomy resolves for a scale pair — used to pick, from
/// the options actually on screen, one of each error family.
ErrorType _scaleError(AnswerOption answer, AnswerOption picked) =>
    ExerciseAttempt.errorTypeFor(
      exerciseType: ExerciseType.scale,
      answer: answer,
      picked: picked,
    );

/// The mascot's speech bubble (Story 1.6) — the only mascot surface on this
/// screen, and the only Fredoka text on it.
Finder _mascotBubble() =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MascotBubble');

/// The sentence the bubble is showing.
String _bubbleText(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: _mascotBubble(), matching: _fredoka()))
    .data!;

/// The bubble's own decoration (background, radius, shadow).
BoxDecoration _bubbleBox(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: _mascotBubble(),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

void main() {
  testWidgets(
    'renders one raised Exercise card (surface-raised / rounded md)',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await _settleFirstMotif(tester, container);

      expect(find.byType(ExerciseCard), findsOneWidget);
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ExerciseCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, CatColors.surfaceRaised);
      expect(decoration.borderRadius, BorderRadius.circular(CatRadii.md));
    },
  );

  testWidgets('options are >= 48dp targets with a button role + name label', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final answer = _state(container).answer;
    final handle = tester.ensureSemantics();

    for (final option in _state(container).options) {
      final size = tester.getSize(
        find
            .ancestor(
              of: find.text(option.nameUi),
              matching: find.byType(FilledButton),
            )
            .first,
      );
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(find.bySemanticsLabel(option.nameUi), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Ouvir de novo'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(answer.nameUi));
    await tester.pump();
    expect(find.textContaining('Isso!'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('options do not overflow at TextScaler.linear(2.2)', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_scaledApp(container));
    await _settleFirstMotif(tester, container);

    // Answer to lay out the result line + "Continuar" too.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(_state(container).answer.nameUi));
    await tester.pump();

    final overflow = errors
        .where((e) => e.exceptionAsString().contains('overflowed'))
        .toList();
    expect(overflow, isEmpty, reason: overflow.map((e) => '$e').join('\n'));
  });

  testWidgets('the mascot bubble does not overflow at TextScaler.linear(2.2)', (
    tester,
  ) async {
    // The wrong branch is the one text scaling hits hardest — the bubble is
    // the largest text surface on the screen, and the correct-answer gate
    // above never lays it out. Its own test rather than a second `pumpWidget`
    // in that one: unmounting a scope leaves an unflushed auto-dispose timer.
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_scaledApp(container));
    await _settleFirstMotif(tester, container);

    final s = _state(container);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.text(s.options.firstWhere((o) => o.id != s.answer.id).nameUi),
    );
    await tester.pump();
    await tester.pumpAndSettle(); // the screen reveals "Continuar"

    expect(_mascotBubble(), findsOneWidget);
    final overflow = errors
        .where((e) => e.exceptionAsString().contains('overflowed'))
        .toList();
    expect(overflow, isEmpty, reason: overflow.map((e) => '$e').join('\n'));
  });

  testWidgets('dark theme: full correct flow works without exceptions', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, brightness: Brightness.dark));
    await _settleFirstMotif(tester, container);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text(_state(container).answer.nameUi));
    await tester.pump();
    expect(find.textContaining('Isso!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(_state(container).index, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plays the interval as a motif, replay is unlimited', (
    tester,
  ) async {
    final fake = FakeAudioService();
    final container = _container(audio: fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    // First exercise is P1 (sax_c4, sax_c4) -> motif of 3 events, never 2.
    expect(fake.playedRefs.length, 3);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Ouvir de novo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
    }
    expect(fake.playedRefs.length, 3 + 5 * 3, reason: 'no replay limit');
  });

  testWidgets('reaction time counts from the first playback; replays do not '
      'reset it', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(
      tester,
      container,
    ); // _enabledAt == the motif length

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ouvir de novo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // replay plays through
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text(_state(container).answer.nameUi));
    await tester.pump();

    final rt = _state(container).attempts.single.reactionTimeMs;
    expect(
      rt,
      closeTo(300 + 3000 + 200, 80),
      reason: 'RT reflects the original enable instant, not the last replay',
    );
  });

  testWidgets('correct answer: positive highlight + flourish, no mascot, '
      'advances', (tester) async {
    final fake = FakeAudioService();
    final container = _container(audio: fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final answer = _state(container).answer; // P1 -> "uníssono justo"
    final playedBefore = fake.playedRefs.length;

    await tester.pump(const Duration(milliseconds: 1100)); // reaction time
    await tester.tap(find.text(answer.nameUi));
    await tester.pump();

    final attempt = _state(container).attempts.single;
    expect(attempt.wasCorrect, isTrue);
    expect(attempt.errorType, isNull);
    expect(attempt.exerciseType, ExerciseType.interval);
    expect(attempt.reactionTimeMs, closeTo(1100, 60));

    // Flourish reuses sax_c4 -> sax_e4 -> sax_g4.
    await tester.pump(const Duration(seconds: 1));
    expect(
      fake.playedRefs.sublist(playedBefore),
      containsAllInOrder(<String>['sax_c4', 'sax_e4', 'sax_g4']),
    );

    // No mascot (no Fredoka text anywhere): EXPERIENCE.md keeps a right answer
    // visual + sonic so the session's rhythm is not interrupted.
    expect(_fredoka(), findsNothing);
    expect(_mascotBubble(), findsNothing);

    // The correct option is highlighted in the positive token, no red on screen.
    final optionButton = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text(answer.nameUi),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    expect(
      optionButton.style?.backgroundColor?.resolve({}),
      CatColors.scaffoldConsonant,
    );

    // Advances to the next exercise (celebration timer).
    await tester.pump(const Duration(seconds: 2));
    expect(_state(container).index, 1);
  });

  testWidgets('correct answer: a second synchronous tap does not double-answer '
      'or double-advance', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final answer = _state(container).answer;
    await tester.pump(const Duration(milliseconds: 500));
    // Two taps before any rebuild.
    await tester.tap(find.text(answer.nameUi), warnIfMissed: false);
    await tester.tap(find.text(answer.nameUi), warnIfMissed: false);
    await tester.pump();

    expect(_state(container).attempts, hasLength(1));

    await tester.pump(const Duration(seconds: 3));
    expect(_state(container).index, 1, reason: 'advanced exactly once');
  });

  testWidgets('wrong answer: gentle state, reveals correct, logs the '
      'ErrorType, no saturated red, mascot explains the confusion', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final s = _state(container);
    final answer = s.answer;
    final wrong = s.options.firstWhere((o) => o.id != answer.id);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text(wrong.nameUi));
    await tester.pump();

    final attempt = _state(container).attempts.single;
    expect(attempt.wasCorrect, isFalse);
    expect(
      attempt.errorType,
      ExerciseAttempt.errorTypeFor(
        exerciseType: ExerciseType.interval,
        answer: answer,
        picked: wrong,
      ),
    );
    expect(attempt.reactionTimeMs, closeTo(800, 60));

    // FR-4: the mascot names the confused pair, never a bare "errado".
    expect(_mascotBubble(), findsOneWidget);
    final message = _bubbleText(tester);
    expect(message, contains(answer.nameUi));
    expect(message, contains(wrong.nameUi));
    expect(
      message,
      errorExplanation(
        answer: answer,
        picked: wrong,
        errorType: attempt.errorType,
      ),
      reason: 'the sentence is built in domain/, not in the widget',
    );
    expect(find.textContaining(answer.nameUi), findsWidgets);
    expect(find.text('Continuar'), findsOneWidget);

    final wrongButton = tester.widget<FilledButton>(
      find
          .ancestor(
            of: find.text(wrong.nameUi),
            matching: find.byType(FilledButton),
          )
          .first,
    );
    final bg = wrongButton.style?.backgroundColor?.resolve({});
    expect(bg, isNot(CatColors.scaffoldDissonant));
    expect(bg, CatColors.surfaceBase);

    // No `ensureVisible` here on purpose: the screen scrolls "Continuar" into
    // view itself after a wrong answer, and a tap that misses the viewport
    // does not dispatch — so this tap is the placement guard.
    await tester.pumpAndSettle(); // the screen reveals "Continuar"
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(_state(container).index, 1);
  });

  testWidgets('a replay that fails after answering keeps the result + '
      '"Continuar"', (tester) async {
    final fake = FakeAudioService();
    final container = _container(audio: fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final s = _state(container);
    final wrong = s.options.firstWhere((o) => o.id != s.answer.id);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(wrong.nameUi));
    await tester.pump();
    expect(find.text('Continuar'), findsOneWidget);

    // Now make the replay fail. The card has scrolled down to reveal
    // "Continuar", so scroll back up the way a learner asking for another
    // listen would — the replay button is above the bubble on this card.
    fake.unplayableRefs.add(s.current.audioSampleRefs.first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ouvir de novo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvir de novo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.textContaining('O som não tocou'), findsOneWidget);
    expect(_mascotBubble(), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);

    await tester.pumpAndSettle(); // the screen reveals "Continuar"
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(_state(container).index, 1);
  });

  testWidgets('end of loop: a "Voltar" button pops back, no mascot', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const IntervalExerciseScreen(),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await _settleFirstMotif(tester, container);

    final notifier = container.read(intervalPracticeProvider.notifier);
    final total = _state(container).loop.length;
    for (var i = 0; i < total; i++) {
      notifier.answer(_state(container).answer, 100);
      notifier.advance();
    }
    await tester.pump();

    expect(find.text('Voltar'), findsOneWidget);
    expect(_fredoka(), findsNothing);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.byType(IntervalExerciseScreen), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('a missing catalog asset shows the "temporary" retry state', (
    tester,
  ) async {
    final container = _container(
      catalogError: const CurriculumError.assetNotFound('x'),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.textContaining('Não consegui carregar'), findsOneWidget);
    expect(find.textContaining('temporário'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a malformed catalog is not shown as "temporary"', (
    tester,
  ) async {
    final container = _container(
      catalogError: const CurriculumError.malformedCatalog(
        'stages',
        'not a list',
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('Algo deu errado'), findsOneWidget);
    expect(find.textContaining('temporário'), findsNothing);
  });

  testWidgets('an unexpected build error shows a plain error state, not '
      '"temporary"', (tester) async {
    final container = _container(catalogError: ArgumentError('boom'));
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('Algo deu errado'), findsOneWidget);
    expect(find.textContaining('temporário'), findsNothing);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('audio playback failure: additive banner + replay recovers', (
    tester,
  ) async {
    final fake = FakeAudioService(unplayableRefs: {'sax_c4'});
    final container = _container(audio: fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    expect(find.textContaining('O som não tocou'), findsOneWidget);
    expect(find.text('Ouvir de novo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Options stay on the card (the banner is additive, not a takeover).
    expect(find.text(_state(container).answer.nameUi), findsOneWidget);

    fake.unplayableRefs.remove('sax_c4');
    await tester.tap(find.text('Ouvir de novo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.textContaining('O som não tocou'), findsNothing);
  });

  testWidgets(
    'keeps the auto-dispose audio service alive while the screen is mounted',
    (tester) async {
      final fake = FakeAudioService();
      final container = ProviderContainer(
        overrides: [
          // `overrideWith` (not `overrideWithValue`) keeps the provider
          // auto-dispose, so a screen that only `ref.read`s it would let the
          // real service be torn down before the first motif.
          audioServiceProvider.overrideWith((ref) {
            ref.onDispose(fake.dispose);
            return fake;
          }),
          catalogAssetBundleProvider.overrideWithValue(_RealCatalogBundle()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await _settleFirstMotif(tester, container);

      expect(
        fake.disposeCount,
        0,
        reason: 'the screen must hold a listener on audioServiceProvider',
      );
      expect(
        fake.playedRefs,
        isNotEmpty,
        reason: 'the first motif must actually play',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('and releases it exactly once when the screen goes away', (
    tester,
  ) async {
    // The other half of the lifetime contract. Holding the provider open for
    // the screen is only correct if letting go is too: a subscription that
    // outlives the screen would keep a real `AudioPlayer` — and its platform
    // resources — alive behind an exercise nobody is looking at.
    final fake = FakeAudioService();
    final container = ProviderContainer(
      overrides: [
        audioServiceProvider.overrideWith((ref) {
          ref.onDispose(fake.dispose);
          return fake;
        }),
        catalogAssetBundleProvider.overrideWithValue(_RealCatalogBundle()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);
    expect(fake.disposeCount, 0);

    await tester.pumpWidget(_app(container, home: const SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(
      fake.disposeCount,
      1,
      reason: 'held open for the screen, released with it — not leaked',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a non-AudioError from playback surfaces the banner, not a raw crash',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          audioServiceProvider.overrideWithValue(_ThrowingAudioService()),
          catalogAssetBundleProvider.overrideWithValue(_RealCatalogBundle()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await _settleFirstMotif(tester, container);

      expect(find.textContaining('O som não tocou'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a card whose audio keeps failing still lets the learner answer',
    (tester) async {
      final fake = FakeAudioService();
      final container = _container(audio: fake);
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await tester.pump();
      await tester.pump();
      fake.unplayableRefs.add(_state(container).current.audioSampleRefs.first);
      await _settleFirstMotif(tester, container);

      expect(find.textContaining('O som não tocou'), findsOneWidget);

      // The options are usable despite the audio failure — the learner is not
      // stranded with only the back button.
      await tester.tap(find.text(_state(container).answer.nameUi).last);
      await tester.pump();
      expect(_state(container).attempts, hasLength(1));
    },
  );

  testWidgets(
    'replaying after a correct answer cancels the pending auto-advance',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await _settleFirstMotif(tester, container);
      final index0 = _state(container).index;

      await tester.tap(find.text(_state(container).answer.nameUi).last);
      await tester.pump(); // answer recorded, flourish begins
      await tester.pump(const Duration(milliseconds: 600)); // flourish done

      await tester.tap(find.text('Ouvir de novo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900)); // past old 700ms

      expect(
        _state(container).index,
        index0,
        reason: 'the replay cancelled the auto-advance',
      );
      expect(find.text('Continuar'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pump();
      await _settleFirstMotif(tester, container);
      expect(_state(container).index, index0 + 1);
    },
  );

  testWidgets('answering stops a replay motif still in flight', (tester) async {
    final fake = FakeAudioService(
      playLatency: const Duration(milliseconds: 250),
    );
    final container = _container(audio: fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    await tester.tap(find.text('Ouvir de novo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // motif mid-note
    final stopsBefore = fake.stopCount;

    final wrong = _state(container).options
        .firstWhere((o) => o.id != _state(container).answer.id);
    await tester.tap(find.text(wrong.nameUi).last);
    await tester.pump();

    expect(
      fake.stopCount,
      greaterThan(stopsBefore),
      reason: 'the in-flight motif is cut when the answer lands',
    );
    await tester.pump(const Duration(seconds: 2));
  });

  // ---------------------------------------------------------------------
  // AC3 — chord and scale render through the same tree as interval.
  // ---------------------------------------------------------------------

  testWidgets('an interval exercise renders through _ActiveExerciseView', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    expect(_activeView(), findsOneWidget);
    expect(find.text('Que intervalo é este?'), findsOneWidget);
    expect(_state(container).current.type, ExerciseType.interval);
  });

  testWidgets('a ChordExercise renders through the same widget tree', (
    tester,
  ) async {
    final fake = FakeAudioService();
    final container = _container(
      audio: fake,
      types: const {ExerciseType.chord},
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    // Same card, same private view, same replay affordance — nothing per type.
    expect(_activeView(), findsOneWidget);
    expect(find.byType(ExerciseCard), findsOneWidget);
    expect(find.text('Ouvir de novo'), findsOneWidget);
    expect(find.text('Que acorde é este?'), findsOneWidget);
    expect(find.text('Que intervalo é este?'), findsNothing);

    final s = _state(container);
    expect(s.current.type, ExerciseType.chord);
    // Options come from chordCatalog, and every one is on screen.
    expect(
      s.options.map((o) => o.id).toSet(),
      isNot(contains('M3')),
      reason: 'a chord card must not offer interval options',
    );
    for (final option in s.options) {
      expect(find.text(option.nameUi), findsOneWidget);
    }
    expect(fake.playedRefs, isNotEmpty);

    await tester.pump(const Duration(milliseconds: 600));
    final wrong = s.options.firstWhere((o) => o.id != s.answer.id);
    await tester.tap(find.text(wrong.nameUi));
    await tester.pump();

    final attempt = _state(container).attempts.single;
    expect(attempt.exerciseType, ExerciseType.chord);
    expect(attempt.errorType, isIn(chordErrorTypes.toList()));
    expect(_mascotBubble(), findsOneWidget);
    expect(_bubbleText(tester), contains(s.answer.nameUi));
    expect(find.text('Continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a ScaleExercise renders through the same widget tree', (
    tester,
  ) async {
    final container = _container(types: const {ExerciseType.scale});
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    expect(_activeView(), findsOneWidget);
    expect(find.byType(ExerciseCard), findsOneWidget);
    expect(find.text('Que escala é esta?'), findsOneWidget);

    final s = _state(container);
    expect(s.current.type, ExerciseType.scale);
    expect(
      s.options.map((o) => o.id).toSet(),
      everyElement(
        isIn(const ['major', 'natural_minor', 'dorian', 'mixolydian']),
      ),
      reason: 'options come from scaleCatalog',
    );
    for (final option in s.options) {
      expect(find.text(option.nameUi), findsOneWidget);
    }

    await tester.pump(const Duration(milliseconds: 600));
    final wrong = s.options.firstWhere((o) => o.id != s.answer.id);
    await tester.tap(find.text(wrong.nameUi));
    await tester.pump();

    final attempt = _state(container).attempts.single;
    expect(attempt.exerciseType, ExerciseType.scale);
    // The `major` id exists in BOTH catalogs; a scale mistake is never filed
    // as a chord-quality one.
    expect(attempt.errorType, isNotNull);
    expect(chordErrorTypes, isNot(contains(attempt.errorType)));
    expect(intervalErrorTypes, isNot(contains(attempt.errorType)));
    expect(find.text('Continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---- Story 1.6: the mascot's explanation on a wrong answer ----

  testWidgets('the bubble is a bubble: accent-soft, rounded/lg, warm shadow, '
      'Fredoka, announced as a live region', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final s = _state(container);
    final wrong = s.options.firstWhere((o) => o.id != s.answer.id);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(wrong.nameUi));
    await tester.pump();

    expect(_mascotBubble(), findsOneWidget);

    final box = _bubbleBox(tester);
    expect(box.color, CatColors.accentSoft);
    expect(
      box.borderRadius,
      BorderRadius.circular(CatRadii.lg),
      reason: 'rounded/lg is reserved for the mascot bubble (UX-DR4)',
    );
    expect(box.boxShadow, isNotEmpty, reason: 'floats above the card');

    // The single Fredoka style in the app, and nothing else uses it.
    final text = tester.widget<Text>(
      find.descendant(of: _mascotBubble(), matching: find.byType(Text)),
    );
    expect(text.style?.fontFamily, CatText.display.fontFamily);
    expect(text.style?.fontWeight, CatText.display.fontWeight);
    expect(text.style?.color, CatColors.inkPrimary);
    expect(_fredoka(), findsOneWidget);

    // Inline and additive: no route was pushed, nothing stacked.
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(IntervalExerciseScreen), findsOneWidget);

    // Screen readers get it, as _ResultLine always did.
    expect(
      tester
          .widgetList<Semantics>(
            find.descendant(
              of: _mascotBubble(),
              matching: find.byType(Semantics),
            ),
          )
          .any((s) => s.properties.liveRegion ?? false),
      isTrue,
      reason: 'the bubble must not lose the liveRegion announcement',
    );
  });

  testWidgets('"Continuar" stays inside a 360x640 viewport after a wrong '
      'answer', (tester) async {
    // The regression this guards: the bubble is the tallest thing on the card
    // and pushed the only way forward ~148 px below the fold on a small phone.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final s = _state(container);
    final wrong = s.options.firstWhere((o) => o.id != s.answer.id);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(wrong.nameUi));
    await tester.pump();
    expect(_mascotBubble(), findsOneWidget);

    // The screen scrolls it into view itself — no `ensureVisible` from here.
    await tester.pumpAndSettle();
    final button = tester.getRect(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(button.bottom, lessThanOrEqualTo(640.0));
    expect(button.top, greaterThanOrEqualTo(0.0));

    // And it actually advances, which a tap outside the viewport would not.
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(_state(container).index, 1);
  });

  testWidgets('the bubble is the dark tokens in dark mode', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, brightness: Brightness.dark));
    await _settleFirstMotif(tester, container);

    final s = _state(container);
    final wrong = s.options.firstWhere((o) => o.id != s.answer.id);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(wrong.nameUi));
    await tester.pump();

    expect(_bubbleBox(tester).color, CatColors.accentSoftDark);
    final text = tester.widget<Text>(
      find.descendant(of: _mascotBubble(), matching: find.byType(Text)),
    );
    expect(text.style?.color, CatColors.inkPrimaryDark);
  });

  testWidgets('no bubble while the motif plays, nor before an answer', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));

    await tester.pump(); // catalog future resolves
    await tester.pump(); // _ActiveExerciseView mounts
    await tester.pump(); // the motif starts
    expect(
      _mascotBubble(),
      findsNothing,
      reason: 'never during the exercise audio (UX-DR4)',
    );

    await tester.pump(_state(container).current.motifTotal);
    await tester.pump();
    expect(
      _mascotBubble(),
      findsNothing,
      reason: 'nothing picked yet — no bubble, no exception',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a one-degree scale error: the bubble names the degree, not the '
      'two modes', (tester) async {
    final container = _container(types: const {ExerciseType.scale});
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final s = _state(container);
    // The pool is all 4 modes and each has exactly one one-degree neighbour,
    // so an altered-degree distractor is always on screen.
    final oneDegreeOff = s.options.firstWhere(
      (o) =>
          o.id != s.answer.id &&
          alteredDegreeNames.containsKey(_scaleError(s.answer, o)),
    );
    final degree = alteredDegreeNames[_scaleError(s.answer, oneDegreeOff)]!;

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(oneDegreeOff.nameUi));
    await tester.pump();

    final message = _bubbleText(tester);
    expect(message, contains(degree), reason: 'the degree is the lesson');
    expect(message, contains(s.answer.nameUi));
    expect(
      _state(container).attempts.single.errorType,
      isIn(<ErrorType>[
        ErrorType.tercaAlterada,
        ErrorType.sextaAlterada,
        ErrorType.setimaAlterada,
      ]),
    );
  });

  testWidgets('a far-miss scale error still names what it was', (tester) async {
    final container = _container(types: const {ExerciseType.scale});
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final s = _state(container);
    final farOff = s.options.firstWhere(
      (o) =>
          o.id != s.answer.id && _scaleError(s.answer, o) == ErrorType.farMiss,
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(farOff.nameUi));
    await tester.pump();

    expect(_state(container).attempts.single.errorType, ErrorType.farMiss);
    final message = _bubbleText(tester);
    expect(message, contains(s.answer.nameUi));
    expect(message, contains(farOff.nameUi));
    expect(message.toLowerCase(), isNot(contains('errado')));
  });

  testWidgets('a correct chord answer flourishes and advances, like interval', (
    tester,
  ) async {
    final container = _container(types: const {ExerciseType.chord});
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text(_state(container).answer.nameUi));
    await tester.pump();

    expect(find.textContaining('Isso!'), findsOneWidget);
    expect(_state(container).attempts.single.errorType, isNull);
    expect(_fredoka(), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(_state(container).index, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the product loop is the full 39, and no card ever mixes types', (
    tester,
  ) async {
    // Story 1.5's visible change: the default loop is no longer intervals only.
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final s = _state(container);
    expect(s.loop.length, 39);
    expect(s.loop.map((q) => q.type).toSet(), {
      ExerciseType.interval,
      ExerciseType.chord,
      ExerciseType.scale,
    });

    // Walk the whole loop through the notifier and check the options the
    // screen would render at every position. A merged pool would put a triad
    // (`[4, 7]`, distance 3 from a major third) on an interval card.
    final notifier = container.read(intervalPracticeProvider.notifier);
    for (var i = 0; i < s.loop.length; i++) {
      final now = _state(container);
      expect(now.index, i);
      for (final option in now.options) {
        expect(
          now.pool[now.current.type],
          contains(option),
          reason:
              'position $i (${now.current.type.name}) offered '
              '"${option.nameUi}" from another catalog',
        );
      }
      notifier.answer(now.answer, 100);
      notifier.advance();
    }
    await tester.pump();
    expect(
      find.text('Você percorreu todos os exercícios de hoje.'),
      findsOneWidget,
    );
  });

  testWidgets('a chord plays block -> arpeggio -> block, 5 events', (
    tester,
  ) async {
    final fake = FakeAudioService();
    final container = _container(
      audio: fake,
      types: const {ExerciseType.chord},
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final refs = _state(container).current.audioSampleRefs;
    expect(refs.length, 4, reason: '[block, root, third, fifth]');
    expect(fake.playedRefs, [refs[0], refs[1], refs[2], refs[3], refs[0]]);
  });

  testWidgets('a scale plays all 8 notes, in the order of its refs', (
    tester,
  ) async {
    final fake = FakeAudioService();
    final container = _container(
      audio: fake,
      types: const {ExerciseType.scale},
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final refs = _state(container).current.audioSampleRefs;
    expect(refs.length, 8);
    // Story 1.4's fixed 3-event contour played `r0, r1, r0` here — two notes
    // out of eight, which is not a scale.
    expect(fake.playedRefs, refs);
  });

  testWidgets('the celebration delay comes from the injected timings', (
    tester,
  ) async {
    // The seam the 1.4 review asked for: a test states the timing it depends
    // on instead of matching a constant inside the widget by hand.
    final container = _container(
      timings: const PracticeTimings(
        advanceDelay: Duration(milliseconds: 2500),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text(_state(container).answer.nameUi));
    await tester.pump();
    // Past the default 700 ms (plus the ~510 ms flourish), still on the same
    // card because the override pushed the auto-advance out to 2500 ms.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(_state(container).index, 0);
    await tester.pump(const Duration(milliseconds: 3000));
    expect(_state(container).index, 1);
  });

  testWidgets('the flourish gap comes from the injected timings', (
    tester,
  ) async {
    // The other half of the seam: `flourishGap` reaches the PhrasePlayer the
    // screen builds. Stretched to 800 ms so the three flourish notes land in
    // separate pumps — at the 170 ms default they would all fire in one.
    final fake = FakeAudioService();
    final container = _container(
      audio: fake,
      timings: const PracticeTimings(flourishGap: Duration(milliseconds: 800)),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    final beforeFlourish = fake.playedRefs.length;
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text(_state(container).answer.nameUi));
    await tester.pump();

    expect(fake.playedRefs.length, beforeFlourish + 1);
    await tester.pump(const Duration(milliseconds: 800));
    expect(fake.playedRefs.length, beforeFlourish + 2);
    await tester.pump(const Duration(milliseconds: 800));
    expect(fake.playedRefs.length, beforeFlourish + 3);
    expect(
      fake.playedRefs.sublist(beforeFlourish),
      PhrasePlayer.flourishRefs,
      reason: 'the injected gap must not change what the flourish plays',
    );
  });

  testWidgets('an empty loop lands on the end-of-loop view, not a crash', (
    tester,
  ) async {
    // `loop.isEmpty` is a branch Story 1.5a introduced — it could not happen
    // before, because the interval loop is never empty. It is reachable now
    // through `practiceExerciseTypesProvider`, so it needs a guard: without
    // one, `_optionsFor(loop, pool, 0)` indexes an empty list.
    final container = _container(types: const <ExerciseType>{});
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(
      find.text('Você percorreu todos os exercícios de hoje.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('intervalos'),
      findsNothing,
      reason: 'the loop holds chords and scales too — naming one would lie',
    );
    expect(find.text('Voltar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ------------------------------------------------- Story 1.7: the session

  testWidgets('two openings of the screen are two sessions', (tester) async {
    // AR-11: the id is minted at the opening and never reused. Epic 2 dedupes
    // ingestion *by* this id, so a repeat would be a dropped session.
    //
    // Opened the way the app opens it — pushed, popped, pushed again — because
    // that is what makes the second opening a second session: the notifier is
    // auto-dispose, so leaving the screen tears it down and coming back builds
    // a new one.
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, home: const _PushToPractice()));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await _settleFirstMotif(tester, container);
    final idA = _state(container).session.sessionId;

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await _settleFirstMotif(tester, container);
    final idB = _state(container).session.sessionId;

    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(idA, matches(uuidV4));
    expect(idB, matches(uuidV4));
    expect(idA, isNot(idB));
  });

  testWidgets('walking the sequence to the end reports it exactly once', (
    tester,
  ) async {
    final reporter = _RecordingReporter();
    final container = _container(reporter: reporter);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);
    final sessionId = _state(container).session.sessionId;

    _answerMany(container, _state(container).loop.length);
    await tester.pump();

    expect(
      find.text('Você percorreu todos os exercícios de hoje.'),
      findsOneWidget,
    );
    expect(reporter.events, hasLength(1));
    expect(reporter.events.single.sessionId, sessionId);
    expect(reporter.events.single.attempts, hasLength(39));
  });

  testWidgets('the end-of-session view rebuilding does not report again', (
    tester,
  ) async {
    // The failure this guards is invisible on screen: emitting from `build`
    // looks identical and doubles Epic 2's progress. So the view is rebuilt on
    // purpose — a theme change, then plain pumps — and the count is re-checked.
    final reporter = _RecordingReporter();
    final container = _container(reporter: reporter);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    _answerMany(container, _state(container).loop.length);
    await tester.pump();
    expect(reporter.events, hasLength(1));

    await tester.pumpWidget(_app(container, brightness: Brightness.dark));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(
      find.text('Você percorreu todos os exercícios de hoje.'),
      findsOneWidget,
    );
    expect(
      reporter.events,
      hasLength(1),
      reason: 'the finished view rebuilds; the session is reported once',
    );
  });

  testWidgets('leaving mid-session reports nothing', (tester) async {
    final reporter = _RecordingReporter();
    final container = _container(reporter: reporter);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container, home: const _PushToPractice()));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await _settleFirstMotif(tester, container);

    _answerMany(container, 5);
    await tester.pump();
    expect(_state(container).attempts, hasLength(5));

    // Back out the way the app does: pop the route, scope still mounted.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(IntervalExerciseScreen), findsNothing);
    expect(
      reporter.events,
      isEmpty,
      reason: 'abandonment discards the attempts — nothing is reported',
    );
  });

  testWidgets('reaching the end without answering reports nothing', (
    tester,
  ) async {
    // The empty loop lands straight on the end view: an ending, but no signal.
    final reporter = _RecordingReporter();
    final container = _container(
      types: const <ExerciseType>{},
      reporter: reporter,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(
      find.text('Você percorreu todos os exercícios de hoje.'),
      findsOneWidget,
    );
    expect(reporter.events, isEmpty);
  });

  testWidgets('the end offer waits for the card in progress, then appears '
      'between exercises', (tester) async {
    final container = _container(
      timings: const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    // Answer the first card well before the target time.
    _answerAndAdvance(container);
    await tester.pump();
    expect(_continuePracticing(), findsNothing);

    // Cross the target while a card is on screen: nothing interrupts it.
    await tester.pump(const Duration(seconds: 31));
    expect(_activeView(), findsOneWidget);
    expect(_continuePracticing(), findsNothing);
    expect(_finishForToday(), findsNothing);
    expect(_state(container).phase, isNot(AnswerPhase.offeringEnd));

    // Only when that card is done does the offer take the gap.
    _answerAndAdvance(container);
    await tester.pump();
    expect(_state(container).phase, AnswerPhase.offeringEnd);
    expect(_activeView(), findsNothing);
    expect(_continuePracticing(), findsOneWidget);
    expect(_finishForToday(), findsOneWidget);
    expect(
      find.text('Você já praticou 2 exercícios nesta sessão.'),
      findsOneWidget,
    );
  });

  testWidgets('the offer counts the work and blames nobody (UX-DR12)', (
    tester,
  ) async {
    final container = _container(
      timings: const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);
    await tester.pump(const Duration(seconds: 31));

    _answerAndAdvance(container);
    await tester.pump();

    expect(
      find.text('Você já praticou 1 exercício nesta sessão.'),
      findsOneWidget,
    );
    // Stopping and continuing are the same widget with the same width: the
    // layout is half of "escolhas iguais".
    final buttons = tester
        .widgetList<FilledButton>(
          find.ancestor(
            of: _continuePracticing().at(0),
            matching: find.byType(FilledButton),
          ),
        )
        .length;
    expect(buttons, 1);
    expect(
      tester
          .widget<SizedBox>(
            find
                .ancestor(
                  of: _continuePracticing(),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      tester
          .widget<SizedBox>(
            find
                .ancestor(
                  of: _finishForToday(),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
    );
    for (final guilt in ['certeza', 'desistir', 'perder', 'Você parou']) {
      expect(find.textContaining(guilt), findsNothing, reason: guilt);
    }
    expect(_fredoka(), findsNothing, reason: 'the mascot does not plead');
  });

  testWidgets('declining the offer keeps the session going, and it does not '
      'come back', (tester) async {
    final reporter = _RecordingReporter();
    final container = _container(
      timings: const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
      reporter: reporter,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);
    await tester.pump(const Duration(seconds: 31));

    _answerAndAdvance(container);
    await tester.pump();
    expect(_state(container).phase, AnswerPhase.offeringEnd);

    await tester.tap(_continuePracticing());
    await tester.pump();
    expect(_state(container).phase, AnswerPhase.answering);
    expect(_state(container).index, 1, reason: 'back on the card that waited');
    expect(reporter.events, isEmpty, reason: 'the session has not ended');

    // Every later gap is past the target too; the offer must not nag.
    await _settleFirstMotif(tester, container);
    for (var i = 0; i < 5; i++) {
      _answerAndAdvance(container);
      await tester.pump();
      expect(_state(container).phase, isNot(AnswerPhase.offeringEnd));
    }

    // ... and the session still ends normally, once, at the end.
    _answerMany(container, _state(container).loop.length);
    await tester.pump();
    expect(reporter.events, hasLength(1));
    expect(reporter.events.single.attempts, hasLength(39));
  });

  testWidgets(
    'accepting the offer ends the session and reports what was done',
    (tester) async {
      final reporter = _RecordingReporter();
      final container = _container(
        timings: const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
        reporter: reporter,
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await _settleFirstMotif(tester, container);
      final sessionId = _state(container).session.sessionId;

      // Two answers inside the target window, one after it — the third is the
      // gap that carries the offer, so three attempts are on the books.
      _answerMany(container, 2);
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      _answerAndAdvance(container);
      await tester.pump();
      expect(_state(container).phase, AnswerPhase.offeringEnd);
      expect(_state(container).attempts, hasLength(3));

      await tester.tap(_finishForToday());
      await tester.pump();

      expect(reporter.events, hasLength(1));
      expect(reporter.events.single.sessionId, sessionId);
      expect(
        reporter.events.single.attempts,
        hasLength(3),
        reason: 'an early ending reports exactly what was answered',
      );
      expect(_state(container).ending, SessionEnd.acceptedOffer);
      expect(
        find.text('Sessão encerrada. Você praticou 3 exercícios nesta sessão.'),
        findsOneWidget,
      );
      expect(
        find.text('Você percorreu todos os exercícios de hoje.'),
        findsNothing,
        reason: 'ending early did not walk the whole sequence',
      );
      expect(find.text('Voltar'), findsOneWidget);

      // Rebuilding this view must not report a second time either.
      await tester.pumpWidget(_app(container, brightness: Brightness.dark));
      await tester.pumpAndSettle();
      expect(reporter.events, hasLength(1));
    },
  );
  testWidgets('the audio service survives the end offer', (tester) async {
    // Review finding on the 1.7 branch: the offer unmounts the exercise card,
    // and the card used to be the only listener on the auto-dispose
    // `audioServiceProvider` — so the real service was torn down mid-session
    // and rebuilt on decline. Nothing was playing at that instant, which is
    // exactly why no existing test caught it.
    final fake = FakeAudioService();
    final container = ProviderContainer(
      overrides: [
        // `overrideWith`, not `overrideWithValue`: the provider has to stay
        // auto-dispose for the teardown to be reachable at all.
        audioServiceProvider.overrideWith((ref) {
          ref.onDispose(fake.dispose);
          return fake;
        }),
        catalogAssetBundleProvider.overrideWithValue(_RealCatalogBundle()),
        practiceTimingsProvider.overrideWithValue(
          const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);
    await tester.pump(const Duration(seconds: 31));

    _answerAndAdvance(container);
    await tester.pump();
    expect(_state(container).phase, AnswerPhase.offeringEnd);
    expect(
      fake.disposeCount,
      0,
      reason: 'the route holds the service open, card or no card',
    );

    await tester.tap(_continuePracticing());
    await tester.pump();
    await _settleFirstMotif(tester, container);

    expect(fake.disposeCount, 0);
    expect(
      container.read(audioServiceProvider),
      same(fake),
      reason: 'declining must not build a second AudioPlayer',
    );
    expect(find.textContaining('O som não tocou'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the audio service survives the end of the session too', (
    tester,
  ) async {
    final fake = FakeAudioService();
    final container = ProviderContainer(
      overrides: [
        audioServiceProvider.overrideWith((ref) {
          ref.onDispose(fake.dispose);
          return fake;
        }),
        catalogAssetBundleProvider.overrideWithValue(_RealCatalogBundle()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    _answerMany(container, _state(container).loop.length);
    await tester.pump();

    expect(find.text('Voltar'), findsOneWidget);
    expect(
      fake.disposeCount,
      0,
      reason: 'released with the route, not with the last card',
    );
  });

  testWidgets('a reporter that throws does not take the session down', (
    tester,
  ) async {
    // Today's reporter only logs. Epic 2 swaps in a database write, and this
    // runs from the auto-advance timer — an escaping exception would surface
    // as an unhandled async error over a report the learner cannot see.
    final reporter = _ThrowingReporter();
    final container = _container(reporter: reporter);
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester, container);

    _answerMany(container, _state(container).loop.length);
    await tester.pump();

    expect(reporter.calls, 1);
    expect(tester.takeException(), isNull);
    expect(
      find.text('Você percorreu todos os exercícios de hoje.'),
      findsOneWidget,
      reason: 'the learner still gets their ending',
    );

    // And it is not retried behind their back: duplicate ingestion is worse
    // than one failed delivery, since Epic 2 dedupes by sessionId.
    await tester.pumpWidget(_app(container, brightness: Brightness.dark));
    await tester.pumpAndSettle();
    expect(reporter.calls, 1);
  });
}

/// A home that pushes the practice screen, so a test can pop back out of it the
/// way the app does — with the `ProviderScope` still mounted.
class _PushToPractice extends StatelessWidget {
  const _PushToPractice();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const IntervalExerciseScreen(),
          ),
        ),
        child: const Text('go'),
      ),
    ),
  );
}

/// Always throws a non-`AudioError` from playback — exercises `_playMotif`'s
/// broad `catch`.
class _ThrowingAudioService implements AudioService {
  @override
  Future<void> playSample(String ref) async =>
      throw StateError('platform boom');

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
