/// Shared harness for the practice widget suites (`practice_screen_test.dart`,
/// `practice_session_test.dart`): the provider container with every seam the
/// screen needs faked, the app wrapper, the pumps that settle a card, and the
/// finders the tests read the screen with. Split out of the old
/// `interval_exercise_screen_test.dart` in Story 1.8b with only renames — every
/// helper here is what that file had as a private top-level.
library;

import 'dart:io';

import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/curriculo/data/catalog_asset_bundle.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/exercicios/presentation/practice_controller.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository whose `load()` always fails — for the catalog-error path.
class FailingRepo implements CurriculoRepository {
  FailingRepo(this.error);

  final Object error;

  @override
  Future<Curriculum> load() async => throw error;
}

/// Feeds the real `catalog_v1.json` from disk as an in-memory bundle so the
/// load resolves on a microtask (no real file I/O under the fake clock).
class RealCatalogBundle extends CachingAssetBundle {
  RealCatalogBundle()
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
class RecordingReporter implements SessionResultReporter {
  final List<SessionResultReported> events = [];

  @override
  void report(SessionResultReported event) => events.add(event);
}

/// Stands in for the DB-backed reporter Epic 2 will install, on the day the
/// write fails.
class ThrowingReporter implements SessionResultReporter {
  int calls = 0;

  @override
  void report(SessionResultReported event) {
    calls++;
    throw StateError('ingestion is down');
  }
}

/// An in-memory stand-in for the Progressão history (Story 1.8).
///
/// The default in every test: the real one goes through `databaseProvider`,
/// which needs `path_provider` and therefore a platform channel no widget test
/// has. Starting empty is also what makes the loop reproducible here — every
/// position falls back to the root the catalog writes, exactly as it did before
/// this story.
class FakeVariantHistory implements VariantHistoryRepository {
  FakeVariantHistory({List<VariantUse>? seed}) : uses = [...?seed];

  /// Newest first, like the real repository returns.
  final List<VariantUse> uses;

  @override
  Future<List<VariantUse>> recent({required int limit}) async =>
      uses.take(limit).toList();

  @override
  Future<List<VariantUse>> lastUsePerRoot() async {
    // Latest use per (relation, root), over everything recorded — the real
    // repository groups in SQL; here the list is short enough to fold.
    final latest = <(String, String), VariantUse>{};
    for (final use in uses) {
      final key = (use.relationKey, use.rootToken);
      final known = latest[key];
      if (known == null || use.sequence > known.sequence) latest[key] = use;
    }
    return latest.values.toList();
  }

  @override
  Future<void> record({
    required String relationKey,
    required String rootToken,
  }) async {
    uses.insert(
      0,
      VariantUse(
        relationKey: relationKey,
        rootToken: rootToken,
        sequence: uses.isEmpty ? 1 : uses.first.sequence + 1,
      ),
    );
  }
}

/// Stands in for the day the database will not open.
class FailingVariantHistory implements VariantHistoryRepository {
  int reads = 0;
  int writes = 0;

  @override
  Future<List<VariantUse>> recent({required int limit}) async {
    reads++;
    throw StateError('database unavailable');
  }

  @override
  Future<List<VariantUse>> lastUsePerRoot() async {
    reads++;
    throw StateError('database unavailable');
  }

  @override
  Future<void> record({
    required String relationKey,
    required String rootToken,
  }) async {
    writes++;
    throw StateError('database unavailable');
  }
}

ProviderContainer practiceContainer({
  FakeAudioService? audio,
  Object? catalogError,
  Set<ExerciseType>? types,
  PracticeTimings? timings,
  SessionResultReporter? reporter,
  VariantHistoryRepository? variantHistory,
}) {
  return ProviderContainer(
    overrides: [
      audioServiceProvider.overrideWithValue(audio ?? FakeAudioService()),
      // Story 1.8: the anti-decoreba history. Faked by default — see
      // `FakeVariantHistory`.
      variantHistoryRepositoryProvider.overrideWithValue(
        variantHistory ?? FakeVariantHistory(),
      ),
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
        curriculoRepositoryProvider.overrideWithValue(FailingRepo(catalogError))
      else
        catalogAssetBundleProvider.overrideWithValue(RealCatalogBundle()),
    ],
  );
}

/// [home] is swappable so a test can leave the exercise screen the way the app
/// does — popping what is on screen while the `ProviderScope` stays mounted.
/// Unmounting the scope instead unbinds the container's vsync, and any
/// auto-dispose it schedules is never flushed.
Widget practiceApp(
  ProviderContainer container, {
  Brightness brightness = Brightness.light,
  Widget home = const PracticeScreen(),
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
Future<void> settleFirstMotif(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pump(); // catalog future resolves
  await tester.pump(); // ExerciseCardFlow mounts, motif scheduled
  await tester.pump(); // post-frame callback fires the motif
  await tester.pump(stateOf(container).current.motifTotal); // motif gaps elapse
  await tester.pump();
}

PracticeState stateOf(ProviderContainer c) =>
    c.read(practiceControllerProvider).value!;

/// Answers the current card correctly and asks the loop to move on, through the
/// notifier — the same calls the card makes, without waiting out a motif and a
/// flourish per exercise. Used where the subject is the *session* around the
/// cards rather than one card's behaviour.
void answerAndAdvance(ProviderContainer c) {
  final notifier = c.read(practiceControllerProvider.notifier);
  notifier.answer(stateOf(c).answer, 100);
  notifier.advance();
}

/// Walks [count] exercises the same way.
void answerMany(ProviderContainer c, int count) {
  for (var i = 0; i < count; i++) {
    answerAndAdvance(c);
  }
}

/// The offer view's two buttons — equal by construction, so the test names
/// them the way a learner reads them.
Finder continuePracticing() => find.text('Continuar praticando');
Finder finishForToday() => find.text('Encerrar por hoje');

/// The one card that renders every exercise. Finding the *same* widget type
/// for interval, chord and scale is what "no per-type widget" means at
/// runtime; `check_module_boundaries` Rule 6 is the static half.
Finder activeView() => find.byType(ExerciseCardFlow);

Finder fredoka() => find.byWidgetPredicate(
  (w) => w is Text && w.style?.fontFamily == 'Fredoka',
);

/// The practice screen under the maximum accessibility text size.
Widget scaledApp(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: appTheme(Brightness.light),
    home: const MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(2.2)),
      child: PracticeScreen(),
    ),
  ),
);

/// The [ErrorType] the taxonomy resolves for a scale pair — used to pick, from
/// the options actually on screen, one of each error family.
ErrorType scaleError(AnswerOption answer, AnswerOption picked) =>
    ExerciseAttempt.errorTypeFor(
      exerciseType: ExerciseType.scale,
      answer: answer,
      picked: picked,
    );

/// The mascot's speech bubble (Story 1.6) — the only mascot surface on this
/// screen, and the only Fredoka text on it.
Finder mascotBubble() =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_MascotBubble');

/// The sentence the bubble is showing.
String bubbleText(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: mascotBubble(), matching: fredoka()))
    .data!;

/// The bubble's own decoration (background, radius, shadow).
BoxDecoration bubbleBox(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: mascotBubble(),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

/// A home that pushes the practice screen, so a test can pop back out of it the
/// way the app does — with the `ProviderScope` still mounted.
class PushToPractice extends StatelessWidget {
  const PushToPractice({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const PracticeScreen())),
        child: const Text('go'),
      ),
    ),
  );
}

/// Always throws a non-`AudioError` from playback — exercises `_playMotif`'s
/// broad `catch`.
class ThrowingAudioService implements AudioService {
  @override
  Future<void> playSample(String ref) async =>
      throw StateError('platform boom');

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
