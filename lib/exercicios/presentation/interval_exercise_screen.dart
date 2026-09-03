/// The interval-recognition exercise screen (Story 1.4).
///
/// Reached from the Home "Praticar" CTA via `Navigator.push` (one level above
/// the shell). Walks a fixed loop of the catalog's `IntervalExercise`s in stage
/// order, one Exercise card at a time: the interval plays as a short rhythmic
/// motif (never an isolated dyad), replay is free, the answer is a tap on 4
/// generated options, a correct answer gets an immediate visual + sonic flourish
/// (no mascot), and every attempt's reaction time is captured into an
/// [ExerciseAttempt] that is logged (no persistence — that is Story 1.7).
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:catear/audio/audio.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/exercise_attempt.dart';
import '../domain/interval_options.dart';
import '../domain/interval_practice.dart';
import 'exercise_card.dart';
import 'phrase_player.dart';

part 'interval_exercise_screen.g.dart';

/// Where the loop is in answering the current exercise.
enum AnswerPhase { answering, correct, incorrect, finished }

const Object _keep = Object();

/// Immutable snapshot of the fixed interval loop.
@immutable
class IntervalPracticeState {
  IntervalPracticeState({
    required List<IntervalExercise> loop,
    required List<IntervalSpec> pool,
    required this.index,
    required List<IntervalSpec> options,
    required this.phase,
    required List<ExerciseAttempt> attempts,
    this.picked,
  }) : loop = List.unmodifiable(loop),
       pool = List.unmodifiable(pool),
       options = List.unmodifiable(options),
       attempts = List.unmodifiable(attempts);

  /// Every `IntervalExercise` of the catalog, in stage order.
  final List<IntervalExercise> loop;

  /// The distinct `IntervalSpec` distractor pool (13 in v1).
  final List<IntervalSpec> pool;

  /// Position in [loop].
  final int index;

  /// The 4 (or fewer) options for the current exercise, in display order.
  final List<IntervalSpec> options;

  final AnswerPhase phase;

  /// Attempts recorded so far, one per answered exercise. In-memory only;
  /// Story 1.7 consumes these.
  final List<ExerciseAttempt> attempts;

  /// The option the user tapped, once answered.
  final IntervalSpec? picked;

  IntervalExercise get current => loop[index];
  IntervalSpec get answer => current.interval;

  IntervalPracticeState copyWith({
    int? index,
    List<IntervalSpec>? options,
    AnswerPhase? phase,
    List<ExerciseAttempt>? attempts,
    Object? picked = _keep,
  }) => IntervalPracticeState(
    loop: loop,
    pool: pool,
    index: index ?? this.index,
    options: options ?? this.options,
    phase: phase ?? this.phase,
    attempts: attempts ?? this.attempts,
    picked: identical(picked, _keep) ? this.picked : picked as IntervalSpec?,
  );
}

/// Owns the loop / attempt state. `UI → Notifier → domain` (AD-5): it reads the
/// catalog through `curriculoRepositoryProvider` and never touches Drift.
@riverpod
class IntervalPractice extends _$IntervalPractice {
  @override
  Future<IntervalPracticeState> build() async {
    final curriculum = await ref.watch(curriculoRepositoryProvider).load();
    final loop = intervalLoop(curriculum);
    final pool = intervalPool(curriculum);
    return IntervalPracticeState(
      loop: loop,
      pool: pool,
      index: 0,
      options: loop.isEmpty ? const [] : _optionsFor(loop, pool, 0),
      phase: loop.isEmpty ? AnswerPhase.finished : AnswerPhase.answering,
      attempts: const [],
    );
  }

  static List<IntervalSpec> _optionsFor(
    List<IntervalExercise> loop,
    List<IntervalSpec> pool,
    int index,
  ) {
    final exercise = loop[index];
    return intervalOptionsFor(
      exercise.interval,
      pool,
      seed: Object.hash(exercise.interval.id, exercise.direction, index),
    );
  }

  /// Records an answer: builds and logs the [ExerciseAttempt], moves to the
  /// correct / incorrect phase.
  void answer(IntervalSpec option, int reactionTimeMs) {
    final s = state.value;
    if (s == null || s.phase != AnswerPhase.answering) return;

    final attempt = ExerciseAttempt.forInterval(
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

  /// Moves to the next exercise, or to the end-of-loop screen. A no-op unless
  /// an exercise has actually been answered — guards against a double advance
  /// (the celebration timer racing the manual "Continuar").
  void advance() {
    final s = state.value;
    if (s == null) return;
    if (s.phase != AnswerPhase.correct && s.phase != AnswerPhase.incorrect) {
      return;
    }
    final next = s.index + 1;
    if (next >= s.loop.length) {
      state = AsyncData(s.copyWith(phase: AnswerPhase.finished, picked: null));
      return;
    }
    state = AsyncData(
      s.copyWith(
        index: next,
        phase: AnswerPhase.answering,
        options: _optionsFor(s.loop, s.pool, next),
        picked: null,
      ),
    );
  }
}

/// The route screen.
class IntervalExerciseScreen extends ConsumerWidget {
  const IntervalExerciseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            AnswerPhase.finished => _EndOfLoopView(
              onBack: () => Navigator.of(context).pop(),
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

  final IntervalPracticeState state;

  @override
  ConsumerState<_ActiveExerciseView> createState() =>
      _ActiveExerciseViewState();
}

class _ActiveExerciseViewState extends ConsumerState<_ActiveExerciseView> {
  late final PhrasePlayer _player;

  /// Keeps `audioServiceProvider` (auto-dispose) alive for this screen's life.
  ProviderSubscription<AudioService>? _audioSub;

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

  IntervalPracticeState get _s => widget.state;

  @override
  void initState() {
    super.initState();
    // `audioServiceProvider` is auto-dispose. A bare `ref.read` leaves it with
    // zero listeners, so Riverpod tears down the real `_JustAudioService`
    // (firing its `onDispose`) before the first motif plays — every
    // `playSample` would then throw `StateError`. A manual listen holds it
    // open for this screen's lifetime; it is closed in `dispose`.
    final sub = ref.listenManual(audioServiceProvider, (_, _) {});
    _audioSub = sub;
    _player = PhrasePlayer(sub.read());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playMotif();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _player.stop().ignore();
    _audioSub?.close();
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
      await _player.playMotif(_s.current.audioSampleRefs);
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
      // `ArgumentError` (empty refs) — never let a raw exception escape.
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

  Future<void> _pick(IntervalSpec option) async {
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
      _advanceTimer = Timer(const Duration(milliseconds: 700), _advance);
    }
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
            'Que intervalo é este?',
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

  final IntervalSpec option;
  final IntervalPracticeState state;
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

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.state});

  final IntervalPracticeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = state.phase == AnswerPhase.correct;
    final text = correct
        ? 'Isso! ${state.answer.nameUi}.'
        : 'Não foi dessa vez. Era ${state.answer.nameUi}.';
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleSmall,
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

class _EndOfLoopView extends StatelessWidget {
  const _EndOfLoopView({required this.onBack});

  final VoidCallback onBack;

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
                'Você percorreu todos os intervalos de hoje.',
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
