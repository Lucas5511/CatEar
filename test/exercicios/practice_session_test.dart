// The practice *session* around the cards (Story 1.7) and its variation
// history (Story 1.8): session ids, the end offer, the one-shot report, and
// what is recorded. Every test drives the real `PracticeScreen`; one card's
// behaviour is `practice_screen_test.dart`. Split out of
// `interval_exercise_screen_test.dart` in Story 1.8b with only renames.

import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/curriculo/data/catalog_asset_bundle.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/exercicios/presentation/practice_controller.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/practice_harness.dart';

void main() {
  testWidgets('two openings of the screen are two sessions', (tester) async {
    // AR-11: the id is minted at the opening and never reused. Epic 2 dedupes
    // ingestion *by* this id, so a repeat would be a dropped session.
    //
    // Opened the way the app opens it — pushed, popped, pushed again — because
    // that is what makes the second opening a second session: the notifier is
    // auto-dispose, so leaving the screen tears it down and coming back builds
    // a new one.
    final container = practiceContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      practiceApp(container, home: const PushToPractice()),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await settleFirstMotif(tester, container);
    final idA = stateOf(container).session.sessionId;

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await settleFirstMotif(tester, container);
    final idB = stateOf(container).session.sessionId;

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
    final reporter = RecordingReporter();
    final container = practiceContainer(reporter: reporter);
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);
    final sessionId = stateOf(container).session.sessionId;

    answerMany(container, stateOf(container).loop.length);
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
    final reporter = RecordingReporter();
    final container = practiceContainer(reporter: reporter);
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);

    answerMany(container, stateOf(container).loop.length);
    await tester.pump();
    expect(reporter.events, hasLength(1));

    await tester.pumpWidget(
      practiceApp(container, brightness: Brightness.dark),
    );
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
    final reporter = RecordingReporter();
    final container = practiceContainer(reporter: reporter);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      practiceApp(container, home: const PushToPractice()),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await settleFirstMotif(tester, container);

    answerMany(container, 5);
    await tester.pump();
    expect(stateOf(container).attempts, hasLength(5));

    // Back out the way the app does: pop the route, scope still mounted.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(PracticeScreen), findsNothing);
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
    final reporter = RecordingReporter();
    final container = practiceContainer(
      types: const <ExerciseType>{},
      reporter: reporter,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await tester.pumpAndSettle();

    expect(
      find.text('Você percorreu todos os exercícios de hoje.'),
      findsOneWidget,
    );
    expect(reporter.events, isEmpty);
  });

  testWidgets('the end offer waits for the card in progress, then appears '
      'between exercises', (tester) async {
    final container = practiceContainer(
      timings: const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);

    // Answer the first card well before the target time.
    answerAndAdvance(container);
    await tester.pump();
    expect(continuePracticing(), findsNothing);

    // Cross the target while a card is on screen: nothing interrupts it.
    await tester.pump(const Duration(seconds: 31));
    expect(activeView(), findsOneWidget);
    expect(continuePracticing(), findsNothing);
    expect(finishForToday(), findsNothing);
    expect(stateOf(container).phase, isNot(AnswerPhase.offeringEnd));

    // Only when that card is done does the offer take the gap.
    answerAndAdvance(container);
    await tester.pump();
    expect(stateOf(container).phase, AnswerPhase.offeringEnd);
    expect(activeView(), findsNothing);
    expect(continuePracticing(), findsOneWidget);
    expect(finishForToday(), findsOneWidget);
    expect(
      find.text('Você já praticou 2 exercícios nesta sessão.'),
      findsOneWidget,
    );
  });

  testWidgets('the offer counts the work and blames nobody (UX-DR12)', (
    tester,
  ) async {
    final container = practiceContainer(
      timings: const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);
    await tester.pump(const Duration(seconds: 31));

    answerAndAdvance(container);
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
            of: continuePracticing().at(0),
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
                  of: continuePracticing(),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      tester
          .widget<SizedBox>(
            find
                .ancestor(of: finishForToday(), matching: find.byType(SizedBox))
                .first,
          )
          .width,
    );
    for (final guilt in ['certeza', 'desistir', 'perder', 'Você parou']) {
      expect(find.textContaining(guilt), findsNothing, reason: guilt);
    }
    expect(fredoka(), findsNothing, reason: 'the mascot does not plead');
  });

  testWidgets('declining the offer keeps the session going, and it does not '
      'come back', (tester) async {
    final reporter = RecordingReporter();
    final container = practiceContainer(
      timings: const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
      reporter: reporter,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);
    await tester.pump(const Duration(seconds: 31));

    answerAndAdvance(container);
    await tester.pump();
    expect(stateOf(container).phase, AnswerPhase.offeringEnd);

    await tester.tap(continuePracticing());
    await tester.pump();
    expect(stateOf(container).phase, AnswerPhase.answering);
    expect(stateOf(container).index, 1, reason: 'back on the card that waited');
    expect(reporter.events, isEmpty, reason: 'the session has not ended');

    // Every later gap is past the target too; the offer must not nag.
    await settleFirstMotif(tester, container);
    for (var i = 0; i < 5; i++) {
      answerAndAdvance(container);
      await tester.pump();
      expect(stateOf(container).phase, isNot(AnswerPhase.offeringEnd));
    }

    // ... and the session still ends normally, once, at the end.
    answerMany(container, stateOf(container).loop.length);
    await tester.pump();
    expect(reporter.events, hasLength(1));
    expect(reporter.events.single.attempts, hasLength(39));
  });

  testWidgets(
    'accepting the offer ends the session and reports what was done',
    (tester) async {
      final reporter = RecordingReporter();
      final container = practiceContainer(
        timings: const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
        reporter: reporter,
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(practiceApp(container));
      await settleFirstMotif(tester, container);
      final sessionId = stateOf(container).session.sessionId;

      // Two answers inside the target window, one after it — the third is the
      // gap that carries the offer, so three attempts are on the books.
      answerMany(container, 2);
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      answerAndAdvance(container);
      await tester.pump();
      expect(stateOf(container).phase, AnswerPhase.offeringEnd);
      expect(stateOf(container).attempts, hasLength(3));

      await tester.tap(finishForToday());
      await tester.pump();

      expect(reporter.events, hasLength(1));
      expect(reporter.events.single.sessionId, sessionId);
      expect(
        reporter.events.single.attempts,
        hasLength(3),
        reason: 'an early ending reports exactly what was answered',
      );
      expect(stateOf(container).ending, SessionEnd.acceptedOffer);
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
      await tester.pumpWidget(
        practiceApp(container, brightness: Brightness.dark),
      );
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
        catalogAssetBundleProvider.overrideWithValue(RealCatalogBundle()),
        variantHistoryRepositoryProvider.overrideWithValue(
          FakeVariantHistory(),
        ),
        practiceTimingsProvider.overrideWithValue(
          const PracticeTimings(endOfferAfter: Duration(seconds: 30)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);
    await tester.pump(const Duration(seconds: 31));

    answerAndAdvance(container);
    await tester.pump();
    expect(stateOf(container).phase, AnswerPhase.offeringEnd);
    expect(
      fake.disposeCount,
      0,
      reason: 'the route holds the service open, card or no card',
    );

    await tester.tap(continuePracticing());
    await tester.pump();
    await settleFirstMotif(tester, container);

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
        catalogAssetBundleProvider.overrideWithValue(RealCatalogBundle()),
        variantHistoryRepositoryProvider.overrideWithValue(
          FakeVariantHistory(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);

    answerMany(container, stateOf(container).loop.length);
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
    final reporter = ThrowingReporter();
    final container = practiceContainer(reporter: reporter);
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);

    answerMany(container, stateOf(container).loop.length);
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
    await tester.pumpWidget(
      practiceApp(container, brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();
    expect(reporter.calls, 1);
  });

  // ------------------------------------------- Story 1.8: variation history

  testWidgets('every exercise reached is recorded, and only the ones reached', (
    tester,
  ) async {
    final history = FakeVariantHistory();
    final container = practiceContainer(variantHistory: history);
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);

    // The window counts exercises, not sessions: the first card is on screen,
    // so exactly one is on the record.
    expect(history.uses, hasLength(1));
    expect(history.uses.single.relationKey, 'interval:P1:asc');
    expect(history.uses.single.rootToken, 'sax_c4');

    answerMany(container, 4);
    await tester.pump();
    expect(
      history.uses.length,
      5,
      reason: 'one row per exercise presented, none for the ones not reached',
    );

    // …and abandoning here leaves those five behind, which is the point: they
    // were heard.
    await tester.pumpWidget(
      practiceApp(container, home: const SizedBox.shrink()),
    );
    await tester.pumpAndSettle();
    expect(history.uses, hasLength(5));
  });

  testWidgets('a chord never enters the history', (tester) async {
    final history = FakeVariantHistory();
    final container = practiceContainer(
      types: const {ExerciseType.chord},
      variantHistory: history,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);

    final s = stateOf(container);
    expect(s.loop, hasLength(8));
    answerMany(container, s.loop.length - 1);
    await tester.pump();

    expect(
      history.uses,
      isEmpty,
      reason: 'a chord is invariant by decision — nothing to remember',
    );
  });

  test('the second session does not replay the first', () async {
    // The acceptance criterion, through the real notifier: what the first
    // session recorded is what the second one avoids. Driven without a widget
    // tree on purpose — two sessions in one `testWidgets` would mean swapping
    // the `ProviderScope`, which unbinds the first container's vsync and leaves
    // its auto-dispose task pending (see `practiceApp`).
    final history = FakeVariantHistory();

    final first = practiceContainer(variantHistory: history);
    addTearDown(first.dispose);
    final firstLoop = (await first.read(practiceControllerProvider.future))
        .loop;
    answerMany(first, 4);
    // The recording is fire-and-forget; let the queued microtasks run.
    await Future<void>.delayed(Duration.zero);
    expect(history.uses, hasLength(5));

    final second = practiceContainer(variantHistory: history);
    addTearDown(second.dispose);
    final secondLoop = (await second.read(practiceControllerProvider.future))
        .loop;

    expect(secondLoop, hasLength(firstLoop.length));
    for (var i = 0; i < 5; i++) {
      if (firstLoop[i].variant == null) continue; // a chord: invariant
      expect(
        secondLoop[i].audioSampleRefs,
        isNot(firstLoop[i].audioSampleRefs),
        reason: 'position $i sounds the same two sessions running',
      );
    }
  });

  testWidgets('an unavailable database costs variety, never the session', (
    tester,
  ) async {
    final history = FailingVariantHistory();
    final container = practiceContainer(variantHistory: history);
    addTearDown(container.dispose);
    await tester.pumpWidget(practiceApp(container));
    await settleFirstMotif(tester, container);

    final s = stateOf(container);
    expect(s.loop, hasLength(39), reason: 'the whole sequence is still there');
    expect(s.phase, AnswerPhase.answering);
    // Falls back to the catalog's own refs — the P1 of a fresh install.
    expect(s.current.audioSampleRefs, ['sax_c4', 'sax_c4']);
    // Both halves of the history are asked for, and both are allowed to fail:
    // the window (what may not play) and the per-root recency (what orders
    // what is left). Degrading on one but not the other would silently bring
    // back the two-root alternation instead of falling back to the catalog.
    expect(history.reads, 2);

    // The card answers, advances, and the failing writes do not escape as
    // unhandled async errors.
    answerMany(container, 3);
    await tester.pump();
    expect(stateOf(container).index, 3);
    expect(history.writes, greaterThan(1));
    expect(tester.takeException(), isNull);
  });
}
