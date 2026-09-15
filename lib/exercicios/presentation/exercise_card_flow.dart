/// One exercise, from motif to hand-off (Story 1.4, type-agnostic since 1.5a,
/// its own file since 1.8b).
///
/// The exercise plays as a short rhythmic motif (never an isolated dyad),
/// replay is free, the answer is a tap on the generated options, a correct
/// answer gets an immediate visual + sonic flourish (no mascot), a wrong one
/// gets the mascot's bubble naming the confusion (Story 1.6, sentence built in
/// `../domain/error_explanation.dart`), and the reaction time is measured from
/// the first playback finishing to the tap.
///
/// [ExerciseCardFlow] is the shared UI contract of the recognition exercise:
/// it renders a [PracticeState] and reports back through two callbacks,
/// [ExerciseCardFlow.onAnswer] and [ExerciseCardFlow.onAdvance]. It reads no
/// session notifier — the practice session (`practice_screen.dart`) and Story
/// 1.9's levelling each own their notifier and hand the card the callbacks it
/// needs. The card *does* read `audioServiceProvider` and
/// `practiceTimingsProvider` on its own: those are configuration, not session
/// state.
///
/// Nothing here knows which *kind* of exercise it is showing: it consumes
/// [ExerciseQuestion] / [AnswerOption] and the per-type difference lives in
/// `../domain/exercise_question.dart`. `check_module_boundaries` Rule 6 keeps
/// this file (and every sibling) free of the interval types — that static rule,
/// not a widget test, is what stops this tree from being copied per type.
library;

import 'dart:async';

import 'package:catear/audio/audio.dart';
import 'package:catear/core/core.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/error_explanation.dart';
import '../domain/exercise_question.dart';
import '../domain/practice_state.dart';
import 'exercise_card.dart';
import 'phrase_player.dart';
import 'practice_controller.dart';

/// The card for the exercise at `state.index`: motif, replay, options, result
/// line / mascot bubble, and the hand-off to the next exercise.
///
/// Keyed by the owner (typically `ValueKey(state.index)`) so a new exercise
/// mounts a fresh card — the motif, the reaction-time anchor and the one-shot
/// guards are per card, not per screen.
///
/// What the owner owes the card:
///
/// 1. **Keep `audioServiceProvider` alive for the route's lifetime** — e.g.
///    `ref.listenManual(audioServiceProvider, ...)` in `initState`, as
///    `PracticeScreen` does. The provider is auto-dispose and the card only
///    `ref.read`s it; without a listener above, the real `_JustAudioService`
///    is torn down between cards and every `playSample` throws `StateError`.
/// 2. **Update state synchronously in [onAnswer]**, so the owner rebuilds this
///    card with the answered state (`phase` correct / incorrect, `picked` set)
///    in the next frame. On a wrong answer the card scrolls to "Continuar" in
///    a post-frame callback, and that silently no-ops if the button is not
///    laid out by then.
/// 3. **Mount only while there is a current exercise** —
///    `state.index < state.loop.length`; `state.current` throws `RangeError`
///    otherwise. Between exercises (the end offer, the end of the session)
///    the owner shows its own view instead.
class ExerciseCardFlow extends ConsumerStatefulWidget {
  const ExerciseCardFlow({
    required this.state,
    required this.onAnswer,
    required this.onAdvance,
    super.key,
  });

  /// The state to render. The owner rebuilds this widget with the answered
  /// state (`phase` correct / incorrect, `picked` set) after [onAnswer].
  final PracticeState state;

  /// Called exactly once per card, the instant the learner taps an option,
  /// with the reaction time in milliseconds (always >= 1).
  ///
  /// Returns whether the answer was correct. The card needs that answer
  /// *synchronously* — it decides between the flourish + auto-advance and
  /// revealing "Continuar" before the owner has rebuilt it with the new state,
  /// so reading `state.phase` here would read the old one. The rule of what is
  /// correct stays with the owner's notifier (`ExerciseAttempt.forAnswer`),
  /// never duplicated in the widget.
  ///
  /// Must update the owner's state synchronously: the card expects to be
  /// rebuilt with the answered state in the next frame (see the class doc).
  final bool Function(AnswerOption option, int reactionTimeMs) onAnswer;

  /// Called exactly once per card when it hands control to the next exercise:
  /// after the celebration delay on a correct answer, or on "Continuar".
  final VoidCallback onAdvance;

  @override
  ConsumerState<ExerciseCardFlow> createState() => _ExerciseCardFlowState();
}

class _ExerciseCardFlowState extends ConsumerState<ExerciseCardFlow> {
  late final PhrasePlayer _player;
  late final PracticeTimings _timings;

  bool _optionsEnabled = false;
  DateTime? _enabledAt;
  SamplePlaybackFailed? _audioError;
  bool _motifInFlight = false;

  /// Set the instant the user taps an option, before the owner's rebuild —
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
    // life (see `PracticeScreen`). Without that, Riverpod would tear down the
    // real `_JustAudioService` between cards and every `playSample` would
    // throw `StateError`.
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
    final wasCorrect = widget.onAnswer(option, elapsedMs > 0 ? elapsedMs : 1);

    if (wasCorrect) {
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
    if (mounted) widget.onAdvance();
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
