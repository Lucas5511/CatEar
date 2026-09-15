/// Shared harness for the levelling suites (Story 1.9): the fake Progressão
/// port, the container with every seam the screen needs faked, the app
/// wrapper, and the pumps that settle a card.
///
/// The catalog and audio fakes are the practice's own
/// (`../../exercicios/support/practice_harness.dart`) — the levelling renders
/// the practice's card, so it is settled the same way.
library;

import 'dart:async';

import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/curriculo/data/catalog_asset_bundle.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/nivelamento/nivelamento.dart';
import 'package:catear/nivelamento/presentation/nivelamento_controller.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../exercicios/support/practice_harness.dart'
    show FailingRepo, RealCatalogBundle;

/// An in-memory stand-in for the Progressão's starting-level port.
class FakePlacements implements PlacementRepository {
  FakePlacements({this.seed});

  Placement? seed;

  /// Every `record` call, in order — the levelling must make exactly one.
  final List<({String stageId, int correctCount})> records = [];

  @override
  Future<Placement?> current() async => seed;

  @override
  Future<void> record({
    required String stageId,
    required int correctCount,
  }) async {
    records.add((stageId: stageId, correctCount: correctCount));
    seed = Placement(
      stageId: stageId,
      correctCount: correctCount,
      recordedAt: DateTime.utc(2026, 9, 15),
    );
  }
}

/// Stands in for the day the database will not take the write.
class FailingPlacements implements PlacementRepository {
  int writes = 0;

  @override
  Future<Placement?> current() async => null;

  @override
  Future<void> record({
    required String stageId,
    required int correctCount,
  }) async {
    writes++;
    throw StateError('database unavailable');
  }
}

/// A port whose write never lands until the test says so — to prove the
/// summary's CTA waits for the level before handing over.
class PendingPlacements implements PlacementRepository {
  final Completer<void> write = Completer<void>();

  @override
  Future<Placement?> current() async => null;

  @override
  Future<void> record({required String stageId, required int correctCount}) =>
      write.future;
}

/// Records every provider the container initialises, so a test can prove
/// the levelling never reaches the session reporter or the variation history.
final class ProviderLog extends ProviderObserver {
  final List<Object> added = [];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    added.add(context.provider);
  }
}

ProviderContainer nivelamentoContainer({
  FakeAudioService? audio,
  Object? catalogError,
  PlacementRepository? placements,
  List<ProviderObserver> observers = const [],
}) => ProviderContainer(
  observers: observers,
  overrides: [
    audioServiceProvider.overrideWithValue(audio ?? FakeAudioService()),
    placementRepositoryProvider.overrideWithValue(
      placements ?? FakePlacements(),
    ),
    if (catalogError != null)
      curriculoRepositoryProvider.overrideWithValue(FailingRepo(catalogError))
    else
      catalogAssetBundleProvider.overrideWithValue(RealCatalogBundle()),
  ],
);

/// Counts the hand-offs the screen makes.
class DoneCounter {
  int calls = 0;
  void call() => calls++;
}

Widget nivelamentoApp(
  ProviderContainer container, {
  required VoidCallback onDone,
  Brightness brightness = Brightness.light,
  TextScaler? textScaler,
}) {
  // Always the same tree shape, so re-pumping with another scaler keeps the
  // screen's state (the welcome dismissed, the cards walked) and only
  // re-lays it out — that is how the summary is checked at 2.0.
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: appTheme(brightness),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: textScaler ?? TextScaler.noScaling),
          child: NivelamentoScreen(onDone: onDone),
        ),
      ),
    ),
  );
}

PracticeState stateOf(ProviderContainer c) =>
    c.read(nivelamentoControllerProvider).value!;

/// Taps the welcome's CTA and settles the first card's motif, so that
/// afterwards every ms pumped is reaction time.
Future<void> startAndSettleFirstMotif(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pump(); // catalog future resolves behind the welcome
  await tester.tap(find.text('Vamos lá'));
  await settleMotif(tester, container);
}

/// Pumps past the current card's motif.
Future<void> settleMotif(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pump(); // card mounts, motif scheduled
  await tester.pump(); // post-frame callback fires the motif
  await tester.pump(stateOf(container).current.motifTotal);
  await tester.pump();
}

/// Answers the current card on screen — right or wrong — and walks to the
/// next one the way the learner does: the celebration's auto-advance, or a
/// tap on "Continuar".
Future<void> answerOnScreen(
  WidgetTester tester,
  ProviderContainer container, {
  required bool correct,
}) async {
  final s = stateOf(container);
  final option = correct
      ? s.answer
      : s.options.firstWhere((o) => o.id != s.answer.id);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(option.nameUi));
  await tester.pump();
  if (correct) {
    // Flourish (3 x 170 ms gaps) + the default 700 ms celebration.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 800));
  } else {
    await tester.pump(const Duration(milliseconds: 250)); // scroll to reveal
    await tester.tap(find.text('Continuar'));
    await tester.pump();
  }
}

/// Walks all seven cards with the given verdicts, ending on the summary.
Future<void> walkThrough(
  WidgetTester tester,
  ProviderContainer container,
  List<bool> verdicts,
) async {
  await startAndSettleFirstMotif(tester, container);
  for (var i = 0; i < verdicts.length; i++) {
    if (i > 0) await settleMotif(tester, container);
    await answerOnScreen(tester, container, correct: verdicts[i]);
  }
  await tester.pump();
}

Finder mascotBubble() => find.byType(MascotBubble);

String bubbleText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: mascotBubble(), matching: find.byType(Text)),
    )
    .data!;
