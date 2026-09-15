// The seam Story 1.8b cut, proven on its own: `ExerciseCardFlow` mounted with
// a hand-built `PracticeState` and two recorded callbacks — no catalog, no
// session notifier, nothing in the container but the audio service. If the
// card ever reaches for `practiceControllerProvider` again, the provider log
// below sees it before Story 1.9 (levelling, its own notifier) does.
//
// The card's *behaviour* — texts, timings, bubble, a11y — is protected by
// `practice_screen_test.dart` through the real screen. This file is only the
// contract, and it is also the template a second consumer copies.

import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/core/core.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/exercicios/presentation/phrase_player.dart';
import 'package:catear/exercicios/presentation/practice_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/practice_harness.dart' show ThrowingAudioService;

/// Records every provider the container initialises. The card is allowed
/// `audioServiceProvider` and `practiceTimingsProvider`; the session notifier
/// and the catalog must never appear here.
final class _ProviderLog extends ProviderObserver {
  final List<Object> added = [];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    added.add(context.provider);
  }
}

/// One answered-or-not card, recorded. `verdict` is what `onAnswer` returns —
/// the test plays the notifier's part and simply states whether the tap was
/// right, which is the whole point: the rule is not in the widget.
class _Callbacks {
  _Callbacks({required this.verdict});

  final bool verdict;
  final List<(AnswerOption option, int reactionTimeMs)> answers = [];
  int advances = 0;

  bool onAnswer(AnswerOption option, int reactionTimeMs) {
    answers.add((option, reactionTimeMs));
    return verdict;
  }

  void onAdvance() => advances++;
}

final _unison = AnswerOption(
  id: 'P1',
  nameUi: 'uníssono justo',
  semitoneProfile: const [0],
);
final _third = AnswerOption(
  id: 'M3',
  nameUi: 'terça maior',
  semitoneProfile: const [4],
);
final _fifth = AnswerOption(
  id: 'P5',
  nameUi: 'quinta justa',
  semitoneProfile: const [7],
);
final _octave = AnswerOption(
  id: 'P8',
  nameUi: 'oitava justa',
  semitoneProfile: const [12],
);

/// A single interval question, written by hand — nothing here came through
/// the curriculum or the loop builder.
final _question = ExerciseQuestion(
  type: ExerciseType.interval,
  prompt: 'Que intervalo é este?',
  answer: _third,
  audioSampleRefs: const ['sax_c4', 'sax_e4'],
  motif: const [
    MotifEvent('sax_c4', Duration(milliseconds: 450)),
    MotifEvent('sax_e4', Duration(milliseconds: 450)),
    MotifEvent('sax_c4', Duration(milliseconds: 900)),
  ],
);

PracticeState _state({
  AnswerPhase phase = AnswerPhase.answering,
  AnswerOption? picked,
  List<ExerciseAttempt> attempts = const [],
}) => PracticeState(
  session: PracticeSession(startedAt: DateTime(2026, 9, 15)),
  loop: [_question],
  pool: {
    ExerciseType.interval: [_unison, _third, _fifth, _octave],
  },
  index: 0,
  options: [_unison, _third, _fifth, _octave],
  phase: phase,
  attempts: attempts,
  picked: picked,
);

/// A container with only what the card is entitled to: the audio service.
/// No `practiceControllerProvider` override, no catalog, no history.
ProviderContainer _container(AudioService audio, _ProviderLog log) =>
    ProviderContainer(
      overrides: [audioServiceProvider.overrideWithValue(audio)],
      observers: [log],
    );

/// The card at a fixed key, so re-pumping with an answered state updates the
/// same `State` the way `PracticeScreen` does after `onAnswer`.
Widget _host(
  ProviderContainer container,
  PracticeState state,
  _Callbacks callbacks,
) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: appTheme(Brightness.light),
    home: Scaffold(
      body: ExerciseCardFlow(
        key: const ValueKey(0),
        state: state,
        onAnswer: callbacks.onAnswer,
        onAdvance: callbacks.onAdvance,
      ),
    ),
  ),
);

/// Pumps past the first motif so the options are enabled and the fake clock
/// sits at the reaction-time anchor.
Future<void> _settleFirstMotif(WidgetTester tester) async {
  await tester.pump(); // post-frame callback fires the motif
  await tester.pump(_question.motifTotal); // motif gaps elapse
  await tester.pump();
}

/// An allowlist, not a denylist: the container initialised exactly the two
/// providers the card is entitled to, and nothing else — so a new read of the
/// session notifier, the catalog, the history or the reporter all fail here.
void _expectNoSessionProviderRead(_ProviderLog log) {
  expect(
    log.added,
    unorderedEquals(<Object>[audioServiceProvider, practiceTimingsProvider]),
    reason:
        'the card must not read the session notifier, nor reach the catalog: '
        'only the audio service and the timings are its own',
  );
}

void main() {
  testWidgets('a correct answer: onAnswer once with a reaction time, the '
      'flourish, then onAdvance after the celebration delay', (tester) async {
    final fake = FakeAudioService();
    final log = _ProviderLog();
    final container = _container(fake, log);
    addTearDown(container.dispose);
    final callbacks = _Callbacks(verdict: true);

    await tester.pumpWidget(_host(container, _state(), callbacks));
    await _settleFirstMotif(tester);
    expect(fake.playedRefs, ['sax_c4', 'sax_e4', 'sax_c4']);
    final playedBefore = fake.playedRefs.length;

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(_third.nameUi));
    await tester.pump();

    expect(callbacks.answers, hasLength(1));
    final (option, reactionTimeMs) = callbacks.answers.single;
    expect(option, _third);
    expect(reactionTimeMs, greaterThan(0));
    expect(reactionTimeMs, closeTo(500, 60));

    // The flourish plays on the card's own player, and the hand-off waits for
    // the default `advanceDelay` (700 ms) after it.
    await tester.pump(const Duration(milliseconds: 600));
    expect(fake.playedRefs.sublist(playedBefore), PhrasePlayer.flourishRefs);
    expect(callbacks.advances, 0, reason: 'still celebrating');
    await tester.pump(const Duration(milliseconds: 700));
    expect(callbacks.advances, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(callbacks.advances, 1, reason: 'the timer fires once');

    _expectNoSessionProviderRead(log);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wrong answer: no flourish, "Continuar" once the owner '
      'rebuilds with the answered state, tap -> onAdvance once', (
    tester,
  ) async {
    final fake = FakeAudioService();
    final log = _ProviderLog();
    final container = _container(fake, log);
    addTearDown(container.dispose);
    final callbacks = _Callbacks(verdict: false);

    await tester.pumpWidget(_host(container, _state(), callbacks));
    await _settleFirstMotif(tester);
    final playedBefore = fake.playedRefs.length;

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(_fifth.nameUi));
    await tester.pump();
    expect(callbacks.answers.single.$1, _fifth);

    // Nothing celebrates and nothing advances on its own.
    await tester.pump(const Duration(seconds: 3));
    expect(fake.playedRefs.length, playedBefore, reason: 'no flourish');
    expect(callbacks.advances, 0);

    // The owner answers the way a notifier would: same card, answered state.
    final attempt = ExerciseAttempt.forAnswer(
      exerciseType: ExerciseType.interval,
      answer: _third,
      picked: _fifth,
      reactionTimeMs: 500,
    );
    await tester.pumpWidget(
      _host(
        container,
        _state(
          phase: AnswerPhase.incorrect,
          picked: _fifth,
          attempts: [attempt],
        ),
        callbacks,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continuar'), findsOneWidget);
    expect(
      find.textContaining(_third.nameUi),
      findsWidgets,
      reason: 'the bubble names the right answer',
    );
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(callbacks.advances, 1);

    // A second "Continuar" is swallowed by the card's own guard.
    await tester.tap(find.text('Continuar'), warnIfMissed: false);
    await tester.pump();
    expect(callbacks.advances, 1);

    _expectNoSessionProviderRead(log);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a correct answer, rebuilt with the answered state: "Isso!" and '
      '"Continuar" during the celebration, onAdvance still once', (
    tester,
  ) async {
    final log = _ProviderLog();
    final container = _container(FakeAudioService(), log);
    addTearDown(container.dispose);
    final callbacks = _Callbacks(verdict: true);

    await tester.pumpWidget(_host(container, _state(), callbacks));
    await _settleFirstMotif(tester);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(_third.nameUi));
    await tester.pump();
    expect(callbacks.answers.single.$1, _third);

    // The owner answers the way a notifier would: same key, correct state.
    final attempt = ExerciseAttempt.forAnswer(
      exerciseType: ExerciseType.interval,
      answer: _third,
      picked: _third,
      reactionTimeMs: 500,
    );
    await tester.pumpWidget(
      _host(
        container,
        _state(phase: AnswerPhase.correct, picked: _third, attempts: [attempt]),
        callbacks,
      ),
    );
    await tester.pump();

    expect(find.textContaining('Isso!'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(callbacks.advances, 0, reason: 'still celebrating');

    // The manual "Continuar" and the celebration timer must not both advance.
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(callbacks.advances, 1);
    await tester.pump(const Duration(seconds: 3)); // past flourish + delay
    expect(callbacks.advances, 1, reason: 'the timer does not double-advance');

    _expectNoSessionProviderRead(log);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two synchronous taps call onAnswer once', (tester) async {
    final log = _ProviderLog();
    final container = _container(FakeAudioService(), log);
    addTearDown(container.dispose);
    final callbacks = _Callbacks(verdict: true);

    await tester.pumpWidget(_host(container, _state(), callbacks));
    await _settleFirstMotif(tester);

    await tester.pump(const Duration(milliseconds: 500));
    // Two taps before any rebuild.
    await tester.tap(find.text(_third.nameUi), warnIfMissed: false);
    await tester.tap(find.text(_third.nameUi), warnIfMissed: false);
    await tester.pump();

    expect(callbacks.answers, hasLength(1));
    await tester.pump(const Duration(seconds: 3));
    expect(callbacks.advances, 1, reason: 'and advances exactly once');

    _expectNoSessionProviderRead(log);
  });

  testWidgets('audio failure: additive banner, options usable, a replay '
      'recovers', (tester) async {
    final fake = FakeAudioService(unplayableRefs: {'sax_c4'});
    final log = _ProviderLog();
    final container = _container(fake, log);
    addTearDown(container.dispose);
    final callbacks = _Callbacks(verdict: true);

    await tester.pumpWidget(_host(container, _state(), callbacks));
    await _settleFirstMotif(tester);

    expect(find.textContaining('O som não tocou'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Additive: the replay button and every option are still on the card.
    expect(find.text('Ouvir de novo'), findsOneWidget);
    for (final option in _state().options) {
      expect(find.text(option.nameUi), findsOneWidget);
    }

    fake.unplayableRefs.remove('sax_c4');
    await tester.tap(find.text('Ouvir de novo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.textContaining('O som não tocou'), findsNothing);

    // The options were never locked behind the failure.
    await tester.tap(find.text(_third.nameUi));
    await tester.pump();
    expect(callbacks.answers, hasLength(1));

    _expectNoSessionProviderRead(log);
  });

  testWidgets('a non-AudioError from playback is shown as the same banner, '
      'not rethrown', (tester) async {
    // `_playMotif`'s broad catch: the raw `StateError` is wrapped into a
    // `SamplePlaybackFailed` and lands on the banner like any other failure.
    final log = _ProviderLog();
    final container = _container(ThrowingAudioService(), log);
    addTearDown(container.dispose);
    final callbacks = _Callbacks(verdict: true);

    await tester.pumpWidget(_host(container, _state(), callbacks));
    await _settleFirstMotif(tester);

    expect(find.textContaining('O som não tocou'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(_third.nameUi));
    await tester.pump();
    expect(callbacks.answers, hasLength(1));
    await tester.pump(const Duration(seconds: 3));

    _expectNoSessionProviderRead(log);
  });
}
