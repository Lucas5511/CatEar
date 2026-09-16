/// The levelling notifier (Story 1.9): the second owner of `ExerciseCardFlow`.
///
/// Walks the fixed sequence of `../domain/placement_sequence.dart` one card at
/// a time, records each answer as an [ExerciseAttempt] — the same value the
/// practice records, so the card's error bubble names the confusion exactly as
/// it does there — and, on the last hand-off, writes the resulting level
/// through the Progressão port. Nothing else leaves this notifier: the
/// levelling is not a practice session (AD-2), so it emits no
/// `SessionResultReported` and touches no variation history.
///
/// It reuses [PracticeState] rather than a state of its own because the card
/// consumes that type (Design Notes of the 1.9 spec): `session` is minted for
/// the card's sake and never reported, `endOffered` stays at its default, and
/// `ending` is set to `SessionEnd.reachedEnd` at the end only so the state has
/// a terminal shape — nothing reads it.
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/placement_sequence.dart';

part 'nivelamento_controller.g.dart';

/// No automatic retry: Riverpod 3's default retries any thrown `Exception`
/// with backoff (200 ms → 6.4 s, ~38 s in all) while the state stays
/// `AsyncLoading`, which would leave the learner on a spinner for half a
/// minute before the retry view appears. A `CurriculumError` is retried by
/// the learner, through "Tentar de novo".
Duration? _noRetry(int retryCount, Object error) => null;

/// Owns the levelling's loop / attempt state. `UI → Notifier → domain` (AD-5):
/// it reads the catalog through `curriculoRepositoryProvider` and writes the
/// level through `placementRepositoryProvider`, never touching Drift.
@Riverpod(retry: _noRetry)
class NivelamentoController extends _$NivelamentoController {
  late PlacementRepository _placements;

  /// The write fired at the end, kept so the summary's CTA can wait for it
  /// to land before the boot gate re-reads the level. Completes — never
  /// rejects — whether the write succeeded or was logged as failed.
  Future<void> _recorded = Future<void>.value();

  /// Resolves once the level has been written (or the write has failed and
  /// been logged). Already resolved before the end is reached.
  Future<void> get recorded => _recorded;

  @override
  Future<PracticeState> build() async {
    _placements = ref.watch(placementRepositoryProvider);
    _recorded = Future<void>.value();
    final curriculum = await ref.watch(curriculoRepositoryProvider).load();
    final loop = placementLoop(curriculum);
    final pool = placementPool(curriculum);
    return PracticeState(
      // Minted because the card's state type carries one; never reported.
      session: PracticeSession(startedAt: clock.now()),
      loop: loop,
      pool: pool,
      index: 0,
      options: placementOptionsFor(loop, pool, 0),
      phase: AnswerPhase.answering,
      attempts: const [],
    );
  }

  /// Records an answer and says, synchronously, whether it was right — the
  /// card's `onAnswer` contract. The rule stays in `ExerciseAttempt.forAnswer`.
  ///
  /// Returns `false` when there is nothing to answer (no state yet, or the
  /// card already answered), which also leaves the state untouched.
  bool answer(AnswerOption option, int reactionTimeMs) {
    final s = state.value;
    if (s == null || s.phase != AnswerPhase.answering) return false;

    final attempt = ExerciseAttempt.forAnswer(
      exerciseType: s.current.type,
      answer: s.answer,
      picked: option,
      reactionTimeMs: reactionTimeMs,
    );
    developer.log('$attempt', name: 'catear.nivelamento.attempt');

    state = AsyncData(
      s.copyWith(
        phase: attempt.wasCorrect ? AnswerPhase.correct : AnswerPhase.incorrect,
        picked: option,
        attempts: [...s.attempts, attempt],
      ),
    );
    return attempt.wasCorrect;
  }

  /// Moves to the next card or, after the last one, to the summary — and only
  /// then writes the level. A no-op unless the current card was answered, so
  /// the celebration timer racing the manual "Continuar" cannot advance twice.
  void advance() {
    final s = state.value;
    if (s == null) return;
    if (s.phase != AnswerPhase.correct && s.phase != AnswerPhase.incorrect) {
      return;
    }
    final next = s.index + 1;
    if (next >= s.loop.length) {
      _finish(s);
      return;
    }
    state = AsyncData(
      s.copyWith(
        index: next,
        options: placementOptionsFor(s.loop, s.pool, next),
        picked: null,
        phase: AnswerPhase.answering,
      ),
    );
  }

  /// The end: the summary is shown from the state, and the level is written
  /// **at the end, not per answer** — leaving mid-way persists nothing, so the
  /// next boot starts the levelling from zero.
  ///
  /// A failed write must not take the first victory away: the summary appears
  /// regardless, the failure is logged, and the boot gate will simply not find
  /// a level next time (rare, accepted, logged — Design Notes).
  void _finish(PracticeState s) {
    state = AsyncData(
      s.copyWith(
        phase: AnswerPhase.finished,
        picked: null,
        ending: SessionEnd.reachedEnd,
      ),
    );
    final outcome = placementOutcomeFor(s.attempts);
    // `Future.sync` so a port that throws synchronously is logged like one
    // that rejects — this runs from the card's auto-advance `Timer`, where an
    // escaping exception would be an unhandled error over a write the learner
    // cannot see.
    _recorded =
        Future.sync(
          () => _placements.record(
            stageId: outcome.stageId,
            correctCount: outcome.correctCount,
          ),
        ).then(
          (_) {},
          onError: (Object error, StackTrace stack) {
            developer.log(
              'could not record $outcome — the summary is shown anyway',
              name: 'catear.nivelamento.placement',
              error: error,
              stackTrace: stack,
            );
          },
        );
  }
}
