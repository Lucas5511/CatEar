/// The recognition-practice route (Story 1.4, a session since 1.7, split from
/// the notifier and the card in 1.8b).
///
/// Reached from the Home "Praticar" CTA via `Navigator.push` (one level above
/// the shell). Owns nothing of the loop itself: the session state and its
/// rules live in `practice_controller.dart` ([PracticeController]), and the
/// card that renders one exercise is [ExerciseCardFlow]. This file is the
/// wiring — the loading / retry states around the catalog, the three
/// session-level views (card, end offer, end of session), and the two
/// callbacks that connect the card to the session notifier.
///
/// Nothing here knows which *kind* of exercise it is showing: it consumes
/// [ExerciseQuestion] / [AnswerOption] and the per-type difference lives in
/// `../domain/exercise_question.dart`. `check_module_boundaries` Rule 6 keeps
/// this file (and every sibling) free of the interval types — that static rule,
/// not a widget test, is what stops this tree from being copied per type.
library;

import 'package:catear/audio/audio.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise_question.dart';
import '../domain/practice_state.dart';
import '../domain/session_result.dart';
import 'exercise_card_flow.dart';
import 'practice_controller.dart';

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
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
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

  /// The card's `onAnswer`: records the attempt on the session notifier and
  /// reads back, synchronously, whether it was correct — the rule stays in
  /// `ExerciseAttempt.forAnswer`, the card only needs the verdict.
  bool _answer(AnswerOption option, int reactionTimeMs) {
    ref
        .read(practiceControllerProvider.notifier)
        .answer(option, reactionTimeMs);
    return ref.read(practiceControllerProvider).value?.phase ==
        AnswerPhase.correct;
  }

  void _advance() => ref.read(practiceControllerProvider.notifier).advance();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(practiceControllerProvider);
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
                  onRetry: () => ref.invalidate(practiceControllerProvider),
                )
              : _RetryView(
                  title: 'Algo deu errado',
                  message: 'Não foi possível montar os exercícios.',
                  onRetry: () => ref.invalidate(practiceControllerProvider),
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
              onContinue: () => ref
                  .read(practiceControllerProvider.notifier)
                  .declineEndOffer(),
              onFinish: () => ref
                  .read(practiceControllerProvider.notifier)
                  .acceptEndOffer(),
            ),
            _ => ExerciseCardFlow(
              key: ValueKey(state.index),
              state: state,
              onAnswer: _answer,
              onAdvance: _advance,
            ),
          },
        ),
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
