/// The recognition-practice screen (Story 1.4, made type-agnostic in 1.5a).
///
/// Reached from the Home "Praticar" CTA via `Navigator.push` (one level above
/// the shell). Walks a fixed loop of catalog exercises in stage order, one
/// Exercise card at a time: the exercise plays as a short rhythmic motif (never
/// an isolated dyad), replay is free, the answer is a tap on 4 generated
/// options, a correct answer gets an immediate visual + sonic flourish (no
/// mascot), a wrong one gets the mascot's bubble naming the confusion
/// (Story 1.6, sentence built in `../domain/error_explanation.dart`), and every
/// attempt's reaction time is captured into an [ExerciseAttempt].
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
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:catear/audio/audio.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/error_explanation.dart';
import '../domain/exercise_attempt.dart';
import '../domain/exercise_question.dart';
import '../domain/exercise_variation.dart';
import '../domain/interval_options.dart';
import '../domain/interval_practice.dart';
import '../data/session_result_reporter.dart';
import '../domain/practice_state.dart';
import '../domain/session_result.dart';
import 'exercise_card.dart';
import 'phrase_player.dart';

part 'interval_exercise_screen.g.dart';

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
/// **Read once, at mount.** `_ActiveExerciseViewState.initState` reads the
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
class IntervalPractice extends _$IntervalPractice {
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

/// The route screen.
///
/// Stateful for one reason: it owns the subscription that keeps the
/// auto-dispose `audioServiceProvider` alive for the whole route.
///
/// That used to live on the exercise card, which was almost right — a card is
/// mounted for nearly the whole session — but "almost" is where the invariant
/// broke. Story 1.7 added two states with no card under them (the end offer and
/// the end of the session), and unmounting the card unmounted the only
/// listener: the real `_JustAudioService` was torn down while the offer sat on
/// screen, and declining built a second `AudioPlayer` and reconfigured the
/// `AudioSession` mid-session. Nothing was playing at that instant, so it
/// worked — but this is the same lifecycle that once made every `playSample`
/// throw `StateError` (the 1.4 regression), and the offer is 12 minutes deep,
/// where no test was ever going to see it.
///
/// The service now lives and dies with the route, which is what the comment on
/// the card always claimed.
class IntervalExerciseScreen extends ConsumerStatefulWidget {
  const IntervalExerciseScreen({super.key});

  @override
  ConsumerState<IntervalExerciseScreen> createState() =>
      _IntervalExerciseScreenState();
}

class _IntervalExerciseScreenState
    extends ConsumerState<IntervalExerciseScreen> {
  /// Holds `audioServiceProvider` (auto-dispose) open for the route's life.
  /// Closed in [dispose] — held open is only correct if letting go is too, or
  /// a real `AudioPlayer` outlives the screen nobody is looking at.
  ProviderSubscription<AudioService>? _audioSub;

  @override
  void initState() {
    super.initState();
    _audioSub = ref.listenManual(audioServiceProvider, (_, _) {});
  }

  @override
  void dispose() {
    _audioSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(intervalPracticeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Praticar')),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // Only a missing asset is plausibly transient; a malformed catalog or
          // an unknown token is a permanent failure — don't promise "temporary"
          // and an endless retry.
          error: (error, _) => error is AssetNotFound
              ? _RetryView(
                  title: 'Não consegui carregar os exercícios',
                  message: 'Isso costuma ser temporário. Vamos tentar de novo?',
                  onRetry: () => ref.invalidate(intervalPracticeProvider),
                )
              : _RetryView(
                  title: 'Algo deu errado',
                  message: 'Não foi possível montar os exercícios.',
                  onRetry: () => ref.invalidate(intervalPracticeProvider),
                ),
          data: (state) => switch (state.phase) {
            AnswerPhase.finished => _EndOfSessionView(
              state: state,
              onBack: () => Navigator.of(context).pop(),
            ),
            // Between two exercises: the next card has not mounted, so nothing
            // is playing and nothing is half-answered under this.
            AnswerPhase.offeringEnd => _EndOfferView(
              answered: state.attempts.length,
              onContinue: () =>
                  ref.read(intervalPracticeProvider.notifier).declineEndOffer(),
              onFinish: () =>
                  ref.read(intervalPracticeProvider.notifier).acceptEndOffer(),
            ),
            _ => _ActiveExerciseView(key: ValueKey(state.index), state: state),
          },
        ),
      ),
    );
  }
}

class _ActiveExerciseView extends ConsumerStatefulWidget {
  const _ActiveExerciseView({required this.state, super.key});

  final PracticeState state;

  @override
  ConsumerState<_ActiveExerciseView> createState() =>
      _ActiveExerciseViewState();
}

class _ActiveExerciseViewState extends ConsumerState<_ActiveExerciseView> {
  late final PhrasePlayer _player;
  late final PracticeTimings _timings;

  bool _optionsEnabled = false;
  DateTime? _enabledAt;
  SamplePlaybackFailed? _audioError;
  bool _motifInFlight = false;

  /// Set the instant the user taps an option, before the provider rebuild —
  /// stops a second synchronous tap from double-answering / double-flourishing.
  bool _picked = false;

  /// Set the instant we hand control to the next exercise — stops the
  /// celebration timer and the manual "Continuar" from both advancing.
  bool _advanced = false;

  Timer? _advanceTimer;

  /// Anchors "Continuar" so it can be scrolled to. The mascot bubble is the
  /// tallest thing on the card, and on a 360x640 phone it pushes the advance
  /// button ~148 px below the fold — the learner would have to go looking for
  /// the only way forward.
  final GlobalKey _continueKey = GlobalKey();
  bool _continueRevealed = false;

  PracticeState get _s => widget.state;

  @override
  void initState() {
    super.initState();
    // A bare `ref.read` of the auto-dispose `audioServiceProvider` is safe
    // *here* only because the route above holds a listener on it for its whole
    // life (see [IntervalExerciseScreen]). Without that, Riverpod would tear
    // down the real `_JustAudioService` between cards and every `playSample`
    // would throw `StateError`.
    _timings = ref.read(practiceTimingsProvider);
    _player = PhrasePlayer(
      ref.read(audioServiceProvider),
      flourishGap: _timings.flourishGap,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playMotif();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _player.stop().ignore();
    super.dispose();
  }

  Future<void> _playMotif() async {
    if (_motifInFlight) return;
    // A replay request pauses any pending auto-advance — the learner asked to
    // keep listening; they leave via "Continuar".
    _advanceTimer?.cancel();
    _advanceTimer = null;
    setState(() {
      _motifInFlight = true;
      _audioError = null;
    });
    try {
      await _player.playMotif(_s.current.motif);
      if (!mounted) return;
      setState(() {
        _motifInFlight = false;
        _enableOptions();
      });
    } on AudioError catch (error) {
      _showAudioError(
        error is SamplePlaybackFailed
            ? error
            : SamplePlaybackFailed(_refForError(), '$error'),
      );
    } catch (error) {
      // `playMotif` can also surface a `StateError` (service torn down) or an
      // `ArgumentError` (empty motif) — never let a raw exception escape.
      _showAudioError(SamplePlaybackFailed(_refForError(), '$error'));
    }
  }

  String _refForError() {
    final refs = _s.current.audioSampleRefs;
    return refs.isEmpty ? '?' : refs.first;
  }

  /// Anchors the reaction-time clock the first time the learner can act.
  /// Replays do not move it.
  void _enableOptions() {
    if (_optionsEnabled) return;
    _optionsEnabled = true;
    _enabledAt = clock.now();
  }

  void _showAudioError(SamplePlaybackFailed error) {
    if (!mounted) return;
    setState(() {
      _motifInFlight = false;
      _audioError = error;
      // Don't strand the learner on a card whose audio keeps failing: enable
      // the options so they can still answer or move on. The banner explains.
      _enableOptions();
    });
  }

  Future<void> _pick(AnswerOption option) async {
    if (_picked || !_optionsEnabled || _s.phase != AnswerPhase.answering) {
      return;
    }
    setState(() => _picked = true);

    // Cut any motif still sequencing so the interval audio does not keep
    // playing under the result line.
    _player.stop().ignore();

    // Reaction time from the first playback finishing to this tap; replays do
    // not reset [_enabledAt]. The clamp defends against a tap on the same tick
    // as the enable under the fake clock (elapsed == 0) — never a real value.
    final elapsedMs = clock.now().difference(_enabledAt!).inMilliseconds;
    ref
        .read(intervalPracticeProvider.notifier)
        .answer(option, elapsedMs > 0 ? elapsedMs : 1);

    if (ref.read(intervalPracticeProvider).value?.phase ==
        AnswerPhase.correct) {
      await _player.playFlourish();
      if (!mounted) return;
      _advanceTimer?.cancel();
      _advanceTimer = Timer(_timings.advanceDelay, _advance);
    } else {
      // A correct answer auto-advances; a wrong one waits on "Continuar", so
      // that button has to be reachable without hunting for it.
      _revealContinue();
    }
  }

  /// Scrolls the card so "Continuar" sits inside the viewport. Runs after the
  /// frame that first lays the button out, and only once per exercise — a
  /// later replay must not yank the card while the learner is reading.
  void _revealContinue() {
    if (_continueRevealed) return;
    _continueRevealed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _continueKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 1,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  void _advance() {
    if (_advanced) return;
    _advanced = true;
    _advanceTimer?.cancel();
    if (mounted) ref.read(intervalPracticeProvider.notifier).advance();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final theme = Theme.of(context);
    final answered =
        s.phase == AnswerPhase.correct || s.phase == AnswerPhase.incorrect;

    return ExerciseCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.current.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: CatSpacing.x4),
          OutlinedButton.icon(
            onPressed: _playMotif,
            icon: const Icon(Icons.replay),
            label: const Text('Ouvir de novo'),
          ),
          if (_audioError != null) ...[
            const SizedBox(height: CatSpacing.x4),
            const _AudioErrorBanner(),
          ],
          const SizedBox(height: CatSpacing.x5),
          for (final option in s.options)
            _OptionButton(
              option: option,
              state: s,
              enabled: _optionsEnabled && !answered && !_picked,
              onTap: () => _pick(option),
            ),
          if (answered) ...[
            const SizedBox(height: CatSpacing.x3),
            _ResultLine(state: s),
            const SizedBox(height: CatSpacing.x4),
            SizedBox(
              key: _continueKey,
              width: double.infinity,
              child: FilledButton(
                onPressed: _advance,
                child: const Text('Continuar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.option,
    required this.state,
    required this.enabled,
    required this.onTap,
  });

  final AnswerOption option;
  final PracticeState state;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final answered =
        state.phase == AnswerPhase.correct ||
        state.phase == AnswerPhase.incorrect;
    final isAnswer = option.id == state.answer.id;
    final isPicked = option.id == state.picked?.id;

    final consonant = isDark
        ? CatColors.scaffoldConsonantDark
        : CatColors.scaffoldConsonant;
    final mutedInk = isDark
        ? CatColors.inkSecondaryDark
        : CatColors.inkSecondary;

    Color? background;
    Color? foreground;
    var suffix = '';
    if (answered && isAnswer) {
      background = consonant;
      foreground = CatColors.inkPrimary;
      suffix = ', resposta certa';
    } else if (answered && isPicked && !isAnswer) {
      background = isDark ? CatColors.surfaceBaseDark : CatColors.surfaceBase;
      foreground = mutedInk;
      suffix = ', não foi dessa vez';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: CatSpacing.x3),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: '${option.nameUi}$suffix',
        excludeSemantics: true,
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: FilledButton.tonal(
            onPressed: enabled ? onTap : null,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(
                  horizontal: CatSpacing.x4,
                  vertical: CatSpacing.x3,
                ),
              ),
              alignment: Alignment.center,
              backgroundColor: background == null
                  ? null
                  : WidgetStatePropertyAll(background),
              foregroundColor: foreground == null
                  ? null
                  : WidgetStatePropertyAll(foreground),
            ),
            child: Text(
              option.nameUi,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under the options once an exercise is answered.
///
/// Correct: the plain celebratory line, no mascot — `EXPERIENCE.md` is explicit
/// that a right answer stays visual + sonic so the session keeps its rhythm.
/// Wrong: the mascot's bubble, whose sentence is built in `domain/`
/// ([errorExplanation]); nothing here knows which kind of exercise it was.
class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.state});

  final PracticeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Fails closed: only an explicitly correct phase gets congratulated, so an
    // unexpected phase falls through to the explanation rather than cheering.
    if (state.phase == AnswerPhase.correct) {
      return Semantics(
        liveRegion: true,
        child: Text(
          'Isso! ${state.answer.nameUi}.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
      );
    }
    // The attempt just recorded for this exercise. Read defensively: the last
    // attempt is only this exercise's mistake while nothing re-answers a card,
    // so a correct one is not this error and is dropped —
    // `errorExplanation` still names the right answer from a null pair.
    final last = state.attempts.isEmpty ? null : state.attempts.last;
    final attempt = (last != null && !last.wasCorrect) ? last : null;
    return _MascotBubble(
      message: errorExplanation(
        answer: state.answer,
        picked: state.picked,
        errorType: attempt?.errorType,
      ),
    );
  }
}

/// The mascot's speech bubble (UX-DR4): `rounded/lg`, `accent-soft`, a warm
/// shadow floating it above the card, and the app's only Fredoka style.
///
/// Inline and additive — never a route, never a `showDialog`. `EXPERIENCE.md`
/// asks for "um bubble curto, sem tela cheia de bloqueio", and the epic's
/// "o modal empilha só um nível" is satisfied by stacking nothing at all.
class _MascotBubble extends StatelessWidget {
  const _MascotBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? CatColors.accentSoftDark : CatColors.accentSoft;
    // Verified against `accent-soft` in `test/contrast_test.dart` (>= 4.5:1 in
    // both themes). No red anywhere — UX-DR14, and the palette has none.
    final ink = isDark ? CatColors.inkPrimaryDark : CatColors.inkPrimary;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CatSpacing.x5,
          vertical: CatSpacing.x4,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(CatRadii.lg),
          boxShadow: [
            BoxShadow(
              // Warm, never a cold grey (DESIGN.md § Elevation & Depth).
              color: (isDark ? CatColors.surfaceBaseDark : CatColors.inkPrimary)
                  .withValues(alpha: isDark ? 0.55 : 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          // `CatText.display` stays the app's single Fredoka source; only the
          // scale is stepped down, because 28 is a headline size and this is a
          // two-clause sentence inside a card. Family and weight — the mascot's
          // voice — come from the token untouched.
          style: CatText.display.copyWith(
            fontSize: 20,
            height: 1.35,
            color: ink,
          ),
        ),
      ),
    );
  }
}

/// Additive notice when a motif / replay fails to play. Never replaces the
/// answer UI — a failed replay after answering must not hide "Continuar".
class _AudioErrorBanner extends StatelessWidget {
  const _AudioErrorBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        'O som não tocou agora. Toque "Ouvir de novo".',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CatSpacing.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: CatSpacing.x3),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: CatSpacing.x5),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The offer to stop, made once, between two exercises (UX-DR12).
///
/// Guilt-free by construction: it says what was done, and puts continuing and
/// stopping side by side as the same kind of button — no "tem certeza?", no
/// warning colour, nothing that frames stopping as giving up. Both outcomes
/// count: a session ended here reports its attempts exactly like one walked to
/// the end, which is why the copy can promise that the work is kept.
///
/// It is a view inside the screen, not a `showDialog`: the epic's "o modal
/// empilha só um nível" is satisfied by stacking nothing, and an Android back
/// press here leaves the session (abandonment) rather than dismissing a
/// barrier and stranding the learner in an ambiguous state.
class _EndOfferView extends StatelessWidget {
  const _EndOfferView({
    required this.answered,
    required this.onContinue,
    required this.onFinish,
  });

  /// How many exercises have been answered **in this session** — the progress
  /// the offer reports back. Always >= 1: the offer is only reachable after an
  /// answer.
  ///
  /// The copy says "nesta sessão", not "hoje": this counts `state.attempts`,
  /// which is per session and dropped on abandonment. A second session in the
  /// same day would understate a daily total, and a total across sessions is
  /// something only the Progressão can know (Epic 2).
  final int answered;

  final VoidCallback onContinue;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = answered == 1 ? '1 exercício' : '$answered exercícios';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CatSpacing.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                'Você já praticou $count nesta sessão.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: CatSpacing.x3),
            Text(
              'Dá para continuar ou parar por aqui — o que você fez até agora '
              'conta do mesmo jeito.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: CatSpacing.x5),
            // Same widget, same width, same weight for both: the layout is
            // half of "escolhas iguais", and a tonal/filled pair would nudge.
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                child: const Text('Continuar praticando'),
              ),
            ),
            const SizedBox(height: CatSpacing.x3),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onFinish,
                child: const Text('Encerrar por hoje'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The end of the session, however it got here.
///
/// Renders only; the session was already reported by the notifier before this
/// view existed. Nothing may be emitted from here — this rebuilds on a theme
/// change, a rotation or any neighbouring `setState`.
class _EndOfSessionView extends StatelessWidget {
  const _EndOfSessionView({required this.state, required this.onBack});

  final PracticeState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = state.attempts.length;
    final count = answered == 1 ? '1 exercício' : '$answered exercícios';
    final headline = state.ending == SessionEnd.acceptedOffer
        // Ending early is a complete session, so it is closed like one — no
        // "você parou antes", nothing that reads as a smaller result.
        ? 'Sessão encerrada. Você praticou $count nesta sessão.'
        // Type-agnostic on purpose: the loop holds intervals, chords
        // and scales since Story 1.5, so naming one of them would lie.
        : 'Você percorreu todos os exercícios de hoje.';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CatSpacing.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                headline,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: CatSpacing.x5),
            FilledButton(onPressed: onBack, child: const Text('Voltar')),
          ],
        ),
      ),
    );
  }
}
