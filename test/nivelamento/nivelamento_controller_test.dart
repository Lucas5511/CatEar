import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/nivelamento/presentation/nivelamento_controller.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/nivelamento_harness.dart';

/// Story 1.9 — the levelling notifier on its own: it mounts the fixed
/// sequence as a `PracticeState`, answers the card synchronously, advances,
/// and writes the level through the Progressão port exactly once, at the end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Holds the auto-dispose notifier open the way the screen does, then waits
  /// for the catalog.
  Future<NivelamentoController> ready(ProviderContainer c) async {
    c.listen(nivelamentoControllerProvider, (_, _) {});
    await c.read(nivelamentoControllerProvider.future);
    return c.read(nivelamentoControllerProvider.notifier);
  }

  test('builds the seven-step loop with the easy opener', () async {
    final c = nivelamentoContainer();
    addTearDown(c.dispose);
    await ready(c);

    final s = stateOf(c);
    expect(s.loop, hasLength(7));
    expect(s.index, 0);
    expect(s.phase, AnswerPhase.answering);
    expect(s.attempts, isEmpty);
    expect(s.answer.id, 'P8');
    expect(s.options.map((o) => o.id), contains('P1'));
    expect(s.pool[ExerciseType.interval], hasLength(13));
  });

  test('answer() says synchronously whether it was right and moves the '
      'phase; a second answer on the same card is refused', () async {
    final c = nivelamentoContainer();
    addTearDown(c.dispose);
    final n = await ready(c);

    final wrong = stateOf(c).options.firstWhere((o) => o.id != 'P8');
    expect(n.answer(wrong, 420), isFalse);
    var s = stateOf(c);
    expect(s.phase, AnswerPhase.incorrect);
    expect(s.picked, wrong);
    expect(s.attempts.single.wasCorrect, isFalse);
    expect(s.attempts.single.reactionTimeMs, 420);
    expect(s.attempts.single.errorType, isNotNull);

    // Already answered: refused, state untouched.
    expect(n.answer(s.answer, 10), isFalse);
    expect(stateOf(c).attempts, hasLength(1));

    n.advance();
    s = stateOf(c);
    expect(s.index, 1);
    expect(s.phase, AnswerPhase.answering);
    expect(s.picked, isNull);
    expect(n.answer(s.answer, 300), isTrue);
    expect(stateOf(c).phase, AnswerPhase.correct);
  });

  test('advance() is a no-op on an unanswered card', () async {
    final c = nivelamentoContainer();
    addTearDown(c.dispose);
    final n = await ready(c);

    n.advance();
    expect(stateOf(c).index, 0);
    expect(stateOf(c).phase, AnswerPhase.answering);
  });

  test('later cards take the closest distractors, like the practice', () async {
    final c = nivelamentoContainer();
    addTearDown(c.dispose);
    final n = await ready(c);

    n.answer(stateOf(c).answer, 100);
    n.advance();
    final s = stateOf(c);
    expect(s.answer.id, 'M3');
    expect(s.options.map((o) => o.id).toSet(), {'M3', 'm3', 'P4', 'M2'});
  });

  test('the last hand-off finishes and records the level once, through the '
      'port', () async {
    final placements = FakePlacements();
    final c = nivelamentoContainer(placements: placements);
    addTearDown(c.dispose);
    final n = await ready(c);

    // Right, right, wrong, then right: the level is the third stage.
    const verdicts = [true, true, false, true, true, true, true];
    for (final correct in verdicts) {
      final s = stateOf(c);
      final option = correct
          ? s.answer
          : s.options.firstWhere((o) => o.id != s.answer.id);
      n.answer(option, 100);
      n.advance();
    }

    final s = stateOf(c);
    expect(s.phase, AnswerPhase.finished);
    expect(s.attempts, hasLength(7));
    await n.recorded;
    expect(placements.records, [(stageId: 's-segundas', correctCount: 6)]);

    // A stray second advance (timer racing "Continuar") records nothing more.
    n.advance();
    await n.recorded;
    expect(placements.records, hasLength(1));
  });

  test('zero right: finishes on the first stage, count 0', () async {
    final placements = FakePlacements();
    final c = nivelamentoContainer(placements: placements);
    addTearDown(c.dispose);
    final n = await ready(c);

    for (var i = 0; i < 7; i++) {
      final s = stateOf(c);
      n.answer(s.options.firstWhere((o) => o.id != s.answer.id), 100);
      n.advance();
    }
    await n.recorded;
    expect(placements.records, [(stageId: 's-consonancias', correctCount: 0)]);
  });

  test('a failed write is logged and swallowed: the state still finishes and '
      '`recorded` completes', () async {
    final placements = FailingPlacements();
    final c = nivelamentoContainer(placements: placements);
    addTearDown(c.dispose);
    final n = await ready(c);

    for (var i = 0; i < 7; i++) {
      n.answer(stateOf(c).answer, 100);
      n.advance();
    }
    expect(stateOf(c).phase, AnswerPhase.finished);
    await expectLater(n.recorded, completes);
    expect(placements.writes, 1);
  });

  test('is not a session: nothing recorded before the end, no reporter and '
      'no variation history ever touched', () async {
    final log = ProviderLog();
    final placements = FakePlacements();
    final c = nivelamentoContainer(placements: placements, observers: [log]);
    addTearDown(c.dispose);
    final n = await ready(c);

    for (var i = 0; i < 6; i++) {
      n.answer(stateOf(c).answer, 100);
      n.advance();
    }
    // Six answered, one to go: still nothing on disk.
    expect(placements.records, isEmpty);

    expect(log.added, isNot(contains(sessionResultReporterProvider)));
    expect(log.added, isNot(contains(variantHistoryRepositoryProvider)));
  });

  test('leaving mid-way persists nothing', () async {
    final placements = FakePlacements();
    final c = nivelamentoContainer(placements: placements);
    final n = await ready(c);
    n.answer(stateOf(c).answer, 100);
    n.advance();

    c.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(placements.records, isEmpty);
  });

  test(
    'a catalog failure surfaces as the error the screen retries on',
    () async {
      final c = nivelamentoContainer(
        catalogError: const CurriculumError.assetNotFound('catalog'),
      );
      addTearDown(c.dispose);
      c.listen(nivelamentoControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      // Riverpod 3 retries a failed build with backoff, so the value is a
      // loading-with-error until the retries give up; the screen's `when`
      // reaches its error branch once they do (`nivelamento_screen_test.dart`).
      // What this test pins is that the error is the catalog's own type — the
      // `AssetNotFound` split the retry copy depends on — not a wrapper.
      expect(c.read(nivelamentoControllerProvider).error, isA<AssetNotFound>());
    },
  );
}
