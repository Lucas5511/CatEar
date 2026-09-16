/// The levelling route (Story 1.9): what the app opens on first use.
///
/// Full screen — no tab bar, no login — mounted by `CatEarApp`'s entry gate
/// while the Progressão holds no starting level. Three views in sequence: the
/// mascot's welcome, the seven exercise cards (the same [ExerciseCardFlow] the
/// practice renders, driven by this module's own notifier), and the summary
/// that always ends on a positive note and carries the one CTA out, through
/// [NivelamentoScreen.onDone]. What comes after is the gate's decision — this
/// module knows nothing of the shell.
///
/// Owns nothing of the loop: `nivelamento_controller.dart` holds the state and
/// the rules, `../domain/placement_sequence.dart` the sequence and the level.
/// This file is the wiring, and it meets the card's owner obligations the way
/// `PracticeScreen` does: the card is keyed by exercise, `audioServiceProvider`
/// is held open for the route's life, `onAnswer` updates state synchronously,
/// and the card is mounted only while there is a current exercise.
library;

import 'package:catear/audio/audio.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/placement_sequence.dart';
import 'nivelamento_controller.dart';

/// The route screen.
///
/// Stateful for two reasons: it owns the subscription that keeps the
/// auto-dispose `audioServiceProvider` alive for the whole route (the card
/// only `ref.read`s it — see the 1.4 regression the practice screen's doc
/// tells), and it remembers that the welcome was dismissed. The welcome is a
/// screen concern, not notifier state: the catalog loads behind it, and a
/// retry after a catalog failure must not show the welcome twice.
class NivelamentoScreen extends ConsumerStatefulWidget {
  const NivelamentoScreen({required this.onDone, super.key});

  /// Called once, when the learner taps the summary's CTA — after the level
  /// has been written (or its failure logged). The gate that mounted this
  /// screen replaces it with the shell; nothing here navigates.
  final VoidCallback onDone;

  @override
  ConsumerState<NivelamentoScreen> createState() => _NivelamentoScreenState();
}

class _NivelamentoScreenState extends ConsumerState<NivelamentoScreen> {
  ProviderSubscription<AudioService>? _audioSub;
  bool _started = false;

  /// Set on the first tap of the summary's CTA: a second tap while the write
  /// is still landing must not hand over twice ([NivelamentoScreen.onDone] is
  /// called once).
  bool _leaving = false;

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

  /// The card's `onAnswer`: the notifier records the attempt and answers,
  /// synchronously, whether it was right.
  bool _answer(AnswerOption option, int reactionTimeMs) => ref
      .read(nivelamentoControllerProvider.notifier)
      .answer(option, reactionTimeMs);

  void _advance() => ref.read(nivelamentoControllerProvider.notifier).advance();

  /// The summary's CTA: waits for the level to land (or its failure to be
  /// logged), then hands over. A write that failed does not strand the
  /// learner on the summary — the level stays in memory for this run and the
  /// gate re-reads the database on the next boot.
  Future<void> _goHome() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await ref.read(nivelamentoControllerProvider.notifier).recorded;
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    // Watched from the first frame so the catalog loads behind the welcome.
    final async = ref.watch(nivelamentoControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: !_started
            ? _WelcomeView(onStart: () => setState(() => _started = true))
            : async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                // Same split as the practice: only a missing asset is
                // plausibly transient. Both retry — a white screen is never an
                // option on the first thing a learner sees.
                error: (error, _) => error is AssetNotFound
                    ? _RetryView(
                        title: 'Não consegui carregar os sons',
                        message: 'Isso costuma ser temporário. Vamos tentar de novo?',
                        onRetry: () =>
                            ref.invalidate(nivelamentoControllerProvider),
                      )
                    : _RetryView(
                        title: 'Algo deu errado',
                        message: 'Não foi possível montar o nivelamento.',
                        onRetry: () =>
                            ref.invalidate(nivelamentoControllerProvider),
                      ),
                data: (state) => switch (state.phase) {
                  AnswerPhase.finished => _SummaryView(
                    outcome: placementOutcomeFor(state.attempts),
                    onHome: _leaving ? null : _goHome,
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

/// The mascot's welcome (UX-DR4: the bubble's first of four places), before
/// any audio plays. One CTA in.
class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CatSpacing.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotBubble(
              message:
                  'Oi! Que bom ter você aqui. Vamos ouvir alguns sons juntos '
                  'para eu descobrir de onde a gente parte.',
            ),
            const SizedBox(height: CatSpacing.x5),
            Text(
              'São ${placementSequence.length} trechos curtos. Ouça cada um '
              'e escolha o que você acha que ouviu — não tem nota, não tem '
              'pressa.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: CatSpacing.x5),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                button: true,
                label: 'Vamos lá, começar o nivelamento',
                excludeSemantics: true,
                onTap: onStart,
                child: FilledButton(
                  onPressed: onStart,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
                  ),
                  child: const Text('Vamos lá'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The end, and it is always a good one (UX-DR12, FR-1).
///
/// One right answer or more: the mascot names the first victory. None: the
/// mascot celebrates the first step and says the journey starts here — and
/// **no score appears**, not as a number and not as a fraction. Either way the
/// level is shown by its human name and the single CTA leads into the shell.
class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.outcome, required this.onHome});

  final PlacementOutcome outcome;

  /// `null` while the hand-off is already under way: the button is disabled.
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = outcome.correctCount >= 1
        ? 'Essa foi sua primeira vitória! Você já reconhece sons de ouvido — '
              'e a gente vai treinar isso juntos.'
        : 'Você deu o primeiro passo — é daqui que a gente parte. '
              'Cada som que você ouvir de agora em diante conta.';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CatSpacing.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotBubble(message: message),
            const SizedBox(height: CatSpacing.x5),
            Text(
              'Seu ponto de partida',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: CatSpacing.x2),
            // Plain labelled text: the bubble above is the one live region on
            // this view, so a screen reader announces one thing, in order.
            Text(
              outcome.stageNameUi,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: CatSpacing.x5),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                button: true,
                enabled: onHome != null,
                label: 'Ir para a Home',
                excludeSemantics: true,
                onTap: onHome,
                child: FilledButton(
                  onPressed: onHome,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
                  ),
                  child: const Text('Ir para a Home'),
                ),
              ),
            ),
          ],
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
            SizedBox(
              width: double.infinity,
              child: Semantics(
                button: true,
                label: 'Tentar de novo',
                excludeSemantics: true,
                onTap: onRetry,
                child: FilledButton(
                  onPressed: onRetry,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
                  ),
                  child: const Text('Tentar de novo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
