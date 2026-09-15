/// The practice *session* notifier and its timings (Story 1.4, made
/// type-agnostic in 1.5a, a session since 1.7, split out of the screen file in
/// 1.8b).
///
/// Walks a fixed loop of catalog exercises in stage order, one card at a time,
/// and captures every attempt's reaction time into an [ExerciseAttempt].
///
/// Story 1.7 turned that loop into a *session*: it opens with a `sessionId`
/// (UUID v4), offers to stop once between exercises at the target time
/// (UX-DR12), and on completion reports its attempts exactly once through
/// `sessionResultReporterProvider`. Leaving mid-session reports nothing. The
/// rule that decides which of the two happened is in
/// `../domain/session_result.dart`, and the emission is in the notifier, never
/// in a `build` — the end-of-session view rebuilds, and a duplicate event
/// would be duplicate progress in Epic 2.
///
/// Nothing here knows which *kind* of exercise it is showing: it consumes
/// [ExerciseQuestion] / [AnswerOption] and the per-type difference lives in
/// `../domain/exercise_question.dart`. `check_module_boundaries` Rule 6 keeps
/// this file (and every sibling) free of the interval types — that static rule,
/// not a widget test, is what stops this tree from being copied per type.
///
/// The card that renders one exercise is `exercise_card_flow.dart`, driven by
/// two callbacks rather than by this notifier — so a second consumer (Story
/// 1.9's levelling) can reuse the card with a notifier of its own. The route
/// that wires the two together is `practice_screen.dart`.
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/session_result_reporter.dart';
import '../domain/exercise_attempt.dart';
import '../domain/exercise_question.dart';
import '../domain/exercise_variation.dart';
import '../domain/interval_options.dart';
import '../domain/interval_practice.dart';
import '../domain/practice_state.dart';
import '../domain/session_result.dart';
import 'phrase_player.dart';

part 'practice_controller.g.dart';

/// Which exercise types the practice loop draws from.
///
/// The product value is every tappable type since Story 1.5. It stays a
/// provider so a test can drive a single type through this exact widget tree,
/// which is the behavioural half of AC3 (the static half is Rule 6).
@riverpod
Set<ExerciseType> practiceExerciseTypes(Ref ref) => defaultPracticeTypes;

/// The screen's own timings — everything that is *not* the motif, whose rhythm
/// rides on the question (`../domain/motif.dart`).
///
/// A seam rather than two `const Duration`s inline: Story 1.4 left the widget
/// tests hard-coding `pump()` calls that matched the constants by hand, and
/// Story 1.5 made the motif length vary per type, so a test that cannot state
/// the timings it depends on becomes guesswork. Deferred item from the 1.4
/// review, pulled in here.
///
/// **Read once, at mount.** `_ExerciseCardFlowState.initState` reads the
/// provider and hands `flourishGap` to the `PhrasePlayer` it builds, so this is
/// configuration for the screen's lifetime, not live state: overriding it after
/// a view is mounted changes nothing until the next exercise mounts one.
@immutable
class PracticeTimings {
  const PracticeTimings({
    this.flourishGap = defaultFlourishGap,
    this.advanceDelay = const Duration(milliseconds: 700),
    this.endOfferAfter = const Duration(minutes: 12),
  });

  /// Gap between the notes of the correct-answer flourish.
  final Duration flourishGap;

  /// How long a correct answer is celebrated before the loop auto-advances.
  final Duration advanceDelay;

  /// How long the session runs before it offers to stop (Story 1.7) — the
  /// middle of the 10-15 min target of FR-5, so the offer lands inside the
  /// window rather than at its edge.
  ///
  /// Injectable for the same reason the other two are, only more so: at the
  /// product value a test of the offer would have to wait twelve minutes.
  final Duration endOfferAfter;
}

/// Override in tests to drive the screen with timings a test can name.
@riverpod
PracticeTimings practiceTimings(Ref ref) => const PracticeTimings();

/// Owns the loop / attempt state. `UI → Notifier → domain` (AD-5): it reads the
/// catalog through `curriculoRepositoryProvider` and never touches Drift.
@riverpod
class PracticeController extends _$PracticeController {
  /// Guards the one-shot emission. An instance field, not state: it is a fact
  /// about a side effect already performed, and it must not travel into a
  /// rebuilt widget or a `copyWith`. Reset on every `build`, because a rebuilt
  /// notifier is a new session.
  bool _reported = false;

  late PracticeTimings _timings;

  /// The Progressão module's history of recent variations — the only piece of
  /// persisted state this screen touches, and it touches it through that
  /// module's port (AD-2), never through Drift.
  late VariantHistoryRepository _variantHistory;

  @override
  Future<PracticeState> build() async {
    _reported = false;
    _timings = ref.watch(practiceTimingsProvider);
    final types = ref.watch(practiceExerciseTypesProvider);
    _variantHistory = ref.watch(variantHistoryRepositoryProvider);
    final curriculum = await ref.watch(curriculoRepositoryProvider).load();
    final variantHistory = await _variantHistorySnapshot();
    final loop = practiceLoop(
      curriculum,
      types: types,
      history: variantHistory.window,
      lastUses: variantHistory.lastUses,
    );
    final pool = practicePool(curriculum, types: types);
    if (loop.isNotEmpty) _recordVariant(loop.first);
    return PracticeState(
      // A new session per build: opening the screen twice mints two ids, and
      // so does a retry after a catalog failure (no attempts existed yet).
      session: PracticeSession(startedAt: clock.now()),
      loop: loop,
      pool: pool,
      index: 0,
      options: loop.isEmpty ? const [] : _optionsFor(loop, pool, 0),
      phase: loop.isEmpty ? AnswerPhase.finished : AnswerPhase.answering,
      attempts: const [],
    );
  }

  /// The two halves of the history the loop needs — the window of roots that
  /// may not play, and how long ago each root last played — or two empty lists
  /// if they cannot be read.
  ///
  /// Anti-decoreba is a *preference*: with no history every position falls back
  /// to the root the catalog writes, which is exactly what the app played
  /// before Story 1.8. A database that will not open must cost the learner a
  /// less varied session, never the session itself.
  Future<({List<VariantUse> window, List<VariantUse> lastUses})>
  _variantHistorySnapshot() async {
    try {
      // Both or neither: a window without the recency ordering would degrade
      // silently into the two-root alternation instead of failing visibly.
      final (window, lastUses) = await (
        _variantHistory.recent(limit: variantWindow),
        _variantHistory.lastUsePerRoot(),
      ).wait;
      return (window: window, lastUses: lastUses);
    } catch (error, stack) {
      developer.log(
        'variation history unavailable — practising without it',
        name: 'catear.exercicios.variation',
        error: error,
        stackTrace: stack,
      );
      return (window: const <VariantUse>[], lastUses: const <VariantUse>[]);
    }
  }

  /// Appends [question]'s variation to the history, without waiting for it.
  ///
  /// Called once per exercise **as it is presented**, which is what makes the
  /// window count exercises rather than sessions: someone who practises twice
  /// in a day advances it twice, and someone who leaves after two exercises
  /// advances it by two. Fire-and-forget because a database round-trip has no
  /// business sitting between the learner and the next card; the repository
  /// serialises the writes so they still land in order.
  void _recordVariant(ExerciseQuestion question) {
    final variant = question.variant;
    if (variant == null) return; // an invariant exercise — a chord.
    unawaited(
      _variantHistory
          .record(
            relationKey: variant.relationKey,
            rootToken: variant.rootToken,
          )
          .catchError((Object error, StackTrace stack) {
            developer.log(
              'could not record $variant',
              name: 'catear.exercicios.variation',
              error: error,
              stackTrace: stack,
            );
          }),
    );
  }

  static List<AnswerOption> _optionsFor(
    List<ExerciseQuestion> loop,
    Map<ExerciseType, List<AnswerOption>> pool,
    int index,
  ) {
    final question = loop[index];
    // Per-type pool: the alternatives for a chord are chord qualities, never
    // an interval that happens to sit close in semitones.
    return answerOptionsForQuestion(
      question,
      pool,
      seed: question.optionSeed(index),
    );
  }

  /// Records an answer: builds and logs the [ExerciseAttempt], moves to the
  /// correct / incorrect phase.
  void answer(AnswerOption option, int reactionTimeMs) {
    final s = state.value;
    if (s == null || s.phase != AnswerPhase.answering) return;

    final attempt = ExerciseAttempt.forAnswer(
      exerciseType: s.current.type,
      answer: s.answer,
      picked: option,
      reactionTimeMs: reactionTimeMs,
    );
    developer.log('$attempt', name: 'catear.exercicios.attempt');

    state = AsyncData(
      s.copyWith(
        phase: attempt.wasCorrect ? AnswerPhase.correct : AnswerPhase.incorrect,
        picked: option,
        attempts: [...s.attempts, attempt],
      ),
    );
  }

  /// Moves to the next exercise, to the end offer, or to the end of the
  /// session. A no-op unless an exercise has actually been answered — guards
  /// against a double advance (the celebration timer racing the manual
  /// "Continuar"), and is also what keeps the offer out of a card in progress:
  /// this only ever runs between two exercises.
  void advance() {
    final s = state.value;
    if (s == null) return;
    if (s.phase != AnswerPhase.correct && s.phase != AnswerPhase.incorrect) {
      return;
    }
    final next = s.index + 1;
    if (next >= s.loop.length) {
      _finish(s, SessionEnd.reachedEnd);
      return;
    }
    // The next exercise is selected either way; the offer only holds it back.
    // Declining therefore mounts the card that was already decided, with no
    // second pass through the option generator.
    final moved = s.copyWith(
      index: next,
      options: _optionsFor(s.loop, s.pool, next),
      picked: null,
    );
    if (_shouldOfferEnd(s)) {
      // Not recorded here: the learner may take the offer and never hear this
      // exercise, and a variation nobody heard must not be burned out of next
      // session's pool. `declineEndOffer` records it if they carry on.
      state = AsyncData(
        moved.copyWith(phase: AnswerPhase.offeringEnd, endOffered: true),
      );
      return;
    }
    _recordVariant(s.loop[next]);
    state = AsyncData(moved.copyWith(phase: AnswerPhase.answering));
  }

  /// Whether this gap between exercises is the one that carries the offer:
  /// the target time has passed and the offer has not been made yet.
  bool _shouldOfferEnd(PracticeState s) =>
      !s.endOffered &&
      s.session.elapsedAt(clock.now()) >= _timings.endOfferAfter;

  /// Takes the offer: the session is over, and it counts.
  void acceptEndOffer() {
    final s = state.value;
    if (s == null || s.phase != AnswerPhase.offeringEnd) return;
    _finish(s, SessionEnd.acceptedOffer);
  }

  /// Turns the offer down: back to the card that was already waiting. The
  /// offer does not come back (`endOffered` stays set).
  void declineEndOffer() {
    final s = state.value;
    if (s == null || s.phase != AnswerPhase.offeringEnd) return;
    // The card the offer held back is presented now, so now it is history.
    _recordVariant(s.current);
    state = AsyncData(s.copyWith(phase: AnswerPhase.answering));
  }

  /// Ends the session and reports it — **once**, and never from a `build`.
  ///
  /// Both guards are load-bearing and neither is redundant: the phase checks in
  /// the callers make a second call impossible through the UI, while
  /// [_reported] makes it impossible full stop. Epic 2 aggregates on top of
  /// this event, so a duplicate is duplicated progress, and that is the kind of
  /// bug a happy-path test never sees.
  void _finish(PracticeState s, SessionEnd end) {
    state = AsyncData(
      s.copyWith(phase: AnswerPhase.finished, picked: null, ending: end),
    );
    if (_reported) return;
    final event = sessionResultFor(
      session: s.session,
      end: end,
      attempts: s.attempts,
    );
    // `null` is an abandoned session — here, only the zero-answer walk to the
    // end of an empty sequence. Nothing to report is a normal outcome.
    if (event == null) return;
    // Marked before the call, not after: Epic 2's ingestion is idempotent by
    // `sessionId`, so a retry that duplicated the event would be worse than a
    // delivery that failed once. Today's reporter only logs and cannot throw;
    // the guard is for the DB-backed one that replaces it.
    _reported = true;
    try {
      ref.read(sessionResultReporterProvider).report(event);
    } catch (error, stack) {
      // This runs from an auto-advance `Timer` — an escaping exception would
      // surface as an unhandled async error and take down the session the
      // learner just finished, over a report they cannot see.
      developer.log(
        'session report failed for ${event.sessionId}',
        name: 'catear.exercicios.session',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
