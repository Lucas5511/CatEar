import 'dart:io';

import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/curriculo/data/catalog_asset_bundle.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/exercicios/presentation/exercise_card.dart';
import 'package:catear/exercicios/presentation/interval_exercise_screen.dart';
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

ProviderContainer _container({FakeAudioService? audio, Object? catalogError}) {
  return ProviderContainer(
    overrides: [
      audioServiceProvider.overrideWithValue(audio ?? FakeAudioService()),
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

/// Motif gap total: 450 + 450 + 900 ms.
const Duration _motifDuration = Duration(milliseconds: 1800);

/// Pumps past the catalog load and exactly the first motif playback, so that
/// afterwards the fake clock and the reaction-time anchor (`_enabledAt`) are
/// both at the same instant — every ms pumped after this is reaction time.
Future<void> _settleFirstMotif(WidgetTester tester) async {
  await tester.pump(); // catalog future resolves
  await tester.pump(); // _ActiveExerciseView mounts, motif scheduled
  await tester.pump(); // post-frame callback fires the motif
  await tester.pump(_motifDuration); // motif gaps elapse
  await tester.pump();
}

IntervalPracticeState _state(ProviderContainer c) =>
    c.read(intervalPracticeProvider).value!;

Finder _fredoka() => find.byWidgetPredicate(
  (w) => w is Text && w.style?.fontFamily == 'Fredoka',
);

void main() {
  testWidgets(
    'renders one raised Exercise card (surface-raised / rounded md)',
    (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      await _settleFirstMotif(tester);

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
    await _settleFirstMotif(tester);

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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.2)),
            child: IntervalExerciseScreen(),
          ),
        ),
      ),
    );
    await _settleFirstMotif(tester);

    // Answer to lay out the result line + "Continuar" too.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(_state(container).answer.nameUi));
    await tester.pump();

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
    await _settleFirstMotif(tester);

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
    await _settleFirstMotif(tester);

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
    await _settleFirstMotif(tester); // _enabledAt == 1800 ms

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
    await _settleFirstMotif(tester);

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

    // No mascot (no Fredoka text anywhere).
    expect(_fredoka(), findsNothing);

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
    await _settleFirstMotif(tester);

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
      'ErrorType, no saturated red, no mascot', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await _settleFirstMotif(tester);

    final s = _state(container);
    final answer = s.answer;
    final wrong = s.options.firstWhere((o) => o.id != answer.id);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text(wrong.nameUi));
    await tester.pump();

    final attempt = _state(container).attempts.single;
    expect(attempt.wasCorrect, isFalse);
    expect(attempt.errorType, ExerciseAttempt.errorTypeForIntervalId(wrong.id));
    expect(attempt.reactionTimeMs, closeTo(800, 60));

    expect(find.textContaining('Não foi dessa vez'), findsOneWidget);
    expect(find.textContaining(answer.nameUi), findsWidgets);
    expect(find.text('Continuar'), findsOneWidget);
    expect(_fredoka(), findsNothing);

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
    await _settleFirstMotif(tester);

    final s = _state(container);
    final wrong = s.options.firstWhere((o) => o.id != s.answer.id);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(wrong.nameUi));
    await tester.pump();
    expect(find.text('Continuar'), findsOneWidget);

    // Now make the replay fail.
    fake.unplayableRefs.add(s.current.audioSampleRefs.first);
    await tester.tap(find.text('Ouvir de novo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.textContaining('O som não tocou'), findsOneWidget);
    expect(find.textContaining('Não foi dessa vez'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);

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
    await _settleFirstMotif(tester);

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
    await _settleFirstMotif(tester);

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
      await _settleFirstMotif(tester);

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
    await _settleFirstMotif(tester);
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
      await _settleFirstMotif(tester);

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
      await _settleFirstMotif(tester);

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
      await _settleFirstMotif(tester);
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
      await _settleFirstMotif(tester);
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
    await _settleFirstMotif(tester);

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
