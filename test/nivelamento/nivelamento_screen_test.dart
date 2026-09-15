import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/curriculo/data/catalog_asset_bundle.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../exercicios/support/practice_harness.dart' show RealCatalogBundle;
import 'support/nivelamento_harness.dart';

/// Story 1.9 — the levelling screen through the real widget tree: the
/// welcome, the shared card driven by the levelling's own notifier, and the
/// summary that always ends well.
void main() {
  /// Every verdict pattern used below, named for what it proves.
  const oneWin = [false, true, false, false, false, false, false];
  const allWrong = [false, false, false, false, false, false, false];
  const allRight = [true, true, true, true, true, true, true];

  testWidgets('opens on the mascot\'s welcome: a bubble, one CTA, no card and '
      'no audio yet', (tester) async {
    final fake = FakeAudioService();
    final container = nivelamentoContainer(audio: fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(container, onDone: DoneCounter().call),
    );
    await tester.pump();

    expect(mascotBubble(), findsOneWidget);
    expect(find.text('Vamos lá'), findsOneWidget);
    expect(find.byType(ExerciseCardFlow), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(fake.playedRefs, isEmpty, reason: 'UX-DR4: no bubble over audio');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the first card: a rising octave from the catalog\'s own refs, '
      'the unison among its options, and no bubble while it plays', (
    tester,
  ) async {
    final fake = FakeAudioService();
    final container = nivelamentoContainer(audio: fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(container, onDone: DoneCounter().call),
    );
    await startAndSettleFirstMotif(tester, container);

    expect(find.text('Que intervalo é este?'), findsOneWidget);
    expect(fake.playedRefs, ['sax_c4', 'sax_c5', 'sax_c4']);
    expect(stateOf(container).answer.id, 'P8');
    expect(find.text('uníssono justo'), findsOneWidget);
    expect(find.text('oitava justa'), findsOneWidget);
    expect(
      mascotBubble(),
      findsNothing,
      reason: 'the welcome bubble is gone before the motif plays',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a right answer: flourish, no mascot, auto-advance to a card '
      'keyed by the next exercise', (tester) async {
    final fake = FakeAudioService();
    final container = nivelamentoContainer(audio: fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(container, onDone: DoneCounter().call),
    );
    await startAndSettleFirstMotif(tester, container);
    final played = fake.playedRefs.length;

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('oitava justa'));
    await tester.pump();
    expect(find.textContaining('Isso! oitava justa'), findsOneWidget);
    expect(mascotBubble(), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    expect(fake.playedRefs.length, greaterThan(played), reason: 'flourish');

    await tester.pump(const Duration(milliseconds: 800));
    expect(stateOf(container).index, 1);
    expect(
      tester.widget<ExerciseCardFlow>(find.byType(ExerciseCardFlow)).key,
      const ValueKey(1),
      reason: 'owner contract: a new exercise mounts a fresh card',
    );
    expect(find.text('Que intervalo é este?'), findsOneWidget);
  });

  testWidgets('a wrong answer: the mascot names the confusion, "Continuar" '
      'moves on', (tester) async {
    final container = nivelamentoContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(container, onDone: DoneCounter().call),
    );
    await startAndSettleFirstMotif(tester, container);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('uníssono justo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(mascotBubble(), findsOneWidget);
    expect(bubbleText(tester), contains('oitava justa'));
    expect(find.textContaining('Isso!'), findsNothing);
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(stateOf(container).index, 1);
    expect(stateOf(container).attempts.single.errorType, ErrorType.p1);
  });

  testWidgets('ends with at least one right answer: the first victory is '
      'named, the level too, one CTA; the level is recorded once', (
    tester,
  ) async {
    final placements = FakePlacements();
    final done = DoneCounter();
    final container = nivelamentoContainer(placements: placements);
    addTearDown(container.dispose);
    await tester.pumpWidget(nivelamentoApp(container, onDone: done.call));

    await walkThrough(tester, container, oneWin);

    expect(find.byType(ExerciseCardFlow), findsNothing);
    expect(mascotBubble(), findsOneWidget);
    expect(bubbleText(tester), contains('primeira vitória'));
    // Missed the opener: the level is the first stage, by its human name.
    expect(find.text('Consonâncias'), findsOneWidget);
    expect(find.text('Ir para a Home'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget, reason: 'a single CTA');
    expect(placements.records, [(stageId: 's-consonancias', correctCount: 1)]);

    await tester.tap(find.text('Ir para a Home'));
    await tester.pumpAndSettle();
    expect(done.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all seven right: the last stage, named', (tester) async {
    final placements = FakePlacements();
    final container = nivelamentoContainer(placements: placements);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(container, onDone: DoneCounter().call),
    );

    await walkThrough(tester, container, allRight);

    expect(bubbleText(tester), contains('primeira vitória'));
    expect(find.text('Trítono'), findsOneWidget);
    expect(placements.records, [(stageId: 's-tritono', correctCount: 7)]);
  });

  testWidgets('ends with zero right: the first step is celebrated, no score '
      'anywhere, the first stage named, same CTA', (tester) async {
    final placements = FakePlacements();
    final done = DoneCounter();
    final container = nivelamentoContainer(placements: placements);
    addTearDown(container.dispose);
    await tester.pumpWidget(nivelamentoApp(container, onDone: done.call));

    await walkThrough(tester, container, allWrong);

    expect(mascotBubble(), findsOneWidget);
    expect(bubbleText(tester), contains('primeiro passo'));
    expect(bubbleText(tester), isNot(contains('vitória')));
    // No score: not a digit on the screen, not the word for it.
    final digits = RegExp(r'\d');
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.data ?? '', isNot(matches(digits)));
      expect((text.data ?? '').toLowerCase(), isNot(contains('acert')));
    }
    expect(find.text('Consonâncias'), findsOneWidget);
    expect(find.text('Ir para a Home'), findsOneWidget);
    expect(placements.records, [(stageId: 's-consonancias', correctCount: 0)]);

    await tester.tap(find.text('Ir para a Home'));
    await tester.pumpAndSettle();
    expect(done.calls, 1);
  });

  testWidgets('a failed write does not take the summary away, and the CTA '
      'still hands over', (tester) async {
    final placements = FailingPlacements();
    final done = DoneCounter();
    final container = nivelamentoContainer(placements: placements);
    addTearDown(container.dispose);
    await tester.pumpWidget(nivelamentoApp(container, onDone: done.call));

    await walkThrough(tester, container, oneWin);

    expect(placements.writes, 1);
    expect(bubbleText(tester), contains('primeira vitória'));
    expect(find.text('Consonâncias'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ir para a Home'));
    await tester.pumpAndSettle();
    expect(done.calls, 1);
  });

  testWidgets('a missing catalog asset shows the "temporary" retry state; '
      'retry reaches the card without a second welcome', (tester) async {
    final bundle = _FlakyBundle();
    final container = ProviderContainer(
      overrides: [
        audioServiceProvider.overrideWithValue(FakeAudioService()),
        placementRepositoryProvider.overrideWithValue(FakePlacements()),
        catalogAssetBundleProvider.overrideWithValue(bundle),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(container, onDone: DoneCounter().call),
    );
    await tester.pump();
    await tester.tap(find.text('Vamos lá'));
    await tester.pumpAndSettle();

    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.textContaining('temporário'), findsOneWidget);
    expect(find.byType(ExerciseCardFlow), findsNothing);
    expect(tester.takeException(), isNull);

    bundle.missing = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump(); // catalog future resolves
    await settleMotif(tester, container);

    expect(find.text('Vamos lá'), findsNothing, reason: 'no second welcome');
    expect(find.byType(ExerciseCardFlow), findsOneWidget);
  });

  testWidgets('the retry view appears on the very next frames after the '
      'failure — no automatic retry keeping a spinner up', (tester) async {
    final container = nivelamentoContainer(
      catalogError: const CurriculumError.assetNotFound('catalog'),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(container, onDone: DoneCounter().call),
    );
    await tester.pump();
    await tester.tap(find.text('Vamos lá'));
    // Two frames, no time advanced: Riverpod's default retry would hold the
    // state at loading for ~38 s of backoff here.
    await tester.pump();
    await tester.pump();

    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Ir para a Home" waits for the level to land before handing '
      'over, and hands over once', (tester) async {
    final placements = PendingPlacements();
    final done = DoneCounter();
    final container = nivelamentoContainer(placements: placements);
    addTearDown(container.dispose);
    await tester.pumpWidget(nivelamentoApp(container, onDone: done.call));

    await walkThrough(tester, container, oneWin);
    expect(find.text('Ir para a Home'), findsOneWidget);

    await tester.tap(find.text('Ir para a Home'));
    await tester.pump();
    expect(done.calls, 0, reason: 'the write has not landed yet');
    // A second tap while leaving is swallowed (the button is disabled).
    await tester.tap(find.text('Ir para a Home'), warnIfMissed: false);
    await tester.pump();
    expect(done.calls, 0);

    placements.write.complete();
    await tester.pump();
    expect(done.calls, 1);
    await tester.pump();
    expect(done.calls, 1, reason: 'once');
  });

  testWidgets('a malformed catalog is not shown as "temporary"', (
    tester,
  ) async {
    final container = nivelamentoContainer(
      catalogError: const CurriculumError.malformedCatalog('stages', 'bad'),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(container, onDone: DoneCounter().call),
    );
    await tester.pump();
    await tester.tap(find.text('Vamos lá'));
    await tester.pumpAndSettle();

    expect(find.text('Algo deu errado'), findsOneWidget);
    expect(find.textContaining('temporário'), findsNothing);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('audio failure on a card: the banner, options still usable', (
    tester,
  ) async {
    final fake = FakeAudioService(unplayableRefs: {'sax_c5'});
    final container = nivelamentoContainer(audio: fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(container, onDone: DoneCounter().call),
    );
    await startAndSettleFirstMotif(tester, container);

    expect(find.textContaining('O som não tocou'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('oitava justa'));
    await tester.pump();
    expect(stateOf(container).phase, AnswerPhase.correct);
  });

  testWidgets(
    'keeps the auto-dispose audio service alive across cards, and releases '
    'it once when the screen goes away',
    (tester) async {
      final fake = FakeAudioService();
      final container = ProviderContainer(
        overrides: [
          audioServiceProvider.overrideWith((ref) {
            ref.onDispose(fake.dispose);
            return fake;
          }),
          placementRepositoryProvider.overrideWithValue(FakePlacements()),
          catalogAssetBundleProvider.overrideWithValue(RealCatalogBundle()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        nivelamentoApp(container, onDone: DoneCounter().call),
      );
      await startAndSettleFirstMotif(tester, container);
      await answerOnScreen(tester, container, correct: true);
      await settleMotif(tester, container);

      expect(stateOf(container).index, 1);
      expect(fake.disposeCount, 0, reason: 'held open between cards');
      expect(
        fake.playedRefs.length,
        greaterThan(3),
        reason: '2nd motif played',
      );

      // Leave: the screen is replaced, the subscription closes, the
      // auto-dispose provider goes with it.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold()),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.disposeCount, 1);
    },
  );

  group('accessibility', () {
    Future<List<FlutterErrorDetails>> captureErrors() async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      return errors;
    }

    Iterable<FlutterErrorDetails> overflows(List<FlutterErrorDetails> errors) =>
        errors.where((e) => e.exceptionAsString().contains('overflowed'));

    testWidgets('the welcome does not overflow at TextScaler.linear(2.0), '
        'and its CTA is a labelled >= 48dp button', (tester) async {
      final errors = await captureErrors();
      final container = nivelamentoContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        nivelamentoApp(
          container,
          onDone: DoneCounter().call,
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pump();

      expect(overflows(errors), isEmpty);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Vamos lá')), findsOneWidget);
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
      handle.dispose();
    });

    testWidgets('the summary does not overflow at TextScaler.linear(2.0), '
        'and its CTA is a labelled >= 48dp button', (tester) async {
      final errors = await captureErrors();
      final container = nivelamentoContainer();
      addTearDown(container.dispose);
      // Walked at the default scale (the options sit below the fold at 2.0
      // on the test viewport), then re-laid out at 2.0 on the summary.
      await tester.pumpWidget(
        nivelamentoApp(container, onDone: DoneCounter().call),
      );
      await walkThrough(tester, container, allWrong);
      expect(find.text('Ir para a Home'), findsOneWidget);
      await tester.pumpWidget(
        nivelamentoApp(
          container,
          onDone: DoneCounter().call,
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ir para a Home'), findsOneWidget);
      expect(overflows(errors), isEmpty);
      expect(errors, isEmpty, reason: errors.map((e) => '$e').join('\n'));
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Ir para a Home'), findsOneWidget);
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
      handle.dispose();
    });
  });

  testWidgets('dark theme: the bubble keeps its dark tokens', (tester) async {
    final container = nivelamentoContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      nivelamentoApp(
        container,
        onDone: DoneCounter().call,
        brightness: Brightness.dark,
      ),
    );
    await tester.pump();
    expect(mascotBubble(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// The real catalog, behind a bundle that reports the asset missing until
/// told otherwise — the transient failure the retry copy promises to recover.
class _FlakyBundle extends CachingAssetBundle {
  bool missing = true;
  final RealCatalogBundle _real = RealCatalogBundle();

  @override
  Future<ByteData> load(String key) {
    if (missing) throw FlutterError('missing asset $key');
    return _real.load(key);
  }

  // `CachingAssetBundle` would cache the failed future; go around it.
  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (missing) throw FlutterError('missing asset $key');
    return _real.loadString(key, cache: cache);
  }
}
