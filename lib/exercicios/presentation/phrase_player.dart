/// Sequences [AudioService.playSample] into a short motif so an exercise is
/// always heard *in context* (FR-2 / AC2), never as isolated notes in silence.
///
/// The player is a **dumb executor**: it plays the [MotifEvent] sequence it is
/// handed, in order, with the rhythm carried on each event. Which contour a
/// given exercise gets — `r0, r1, r0` for an interval, block → arpeggio → block
/// for a chord, the 8 notes in order for a scale — is decided in
/// `../domain/motif.dart` and travels on the `ExerciseQuestion`. Story 1.4 had
/// that contour hard-coded here, which truncated a scale to two notes; keeping
/// it out of the presentation layer is what stops per-type branching from
/// growing here (Rule 6 cannot see a `switch` on `ExerciseType`).
///
/// `playSample` interrupts whatever is playing and completes on interruption,
/// so the player fires each event without waiting for the whole sample and uses
/// the event's `hold` as the gap to the next fire; the last event rings out for
/// its own hold and is then cut with `stop()`. Orchestration lives here in
/// `exercicios/`, never inside `audio/`.
library;

import 'dart:async';

import 'package:catear/audio/audio.dart';

import '../domain/motif.dart';

/// The one definition of the flourish gap.
///
/// `PracticeTimings.flourishGap` defaults to it and the screen injects that
/// value into the player, so there is a single number to change — and the
/// sample-onset guard in `test/audio_assets_bundle_test.dart` measures against
/// the same one instead of a second copy that could drift below it.
const Duration defaultFlourishGap = Duration(milliseconds: 170);

/// Plays the motif of one exercise, whatever shape it has. One instance per
/// screen; reused for replays (NFR-5 — no limit, no penalty).
class PhrasePlayer {
  PhrasePlayer(this._audio, {this.flourishGap = defaultFlourishGap});

  final AudioService _audio;

  /// Gap between the notes of the correct-answer flourish. The motif's own
  /// rhythm is not a field any more — it rides on each [MotifEvent].
  final Duration flourishGap;

  /// The correct-answer flourish: a quick major arpeggio reusing existing
  /// samples (no dedicated SFX pack — that is Ask First).
  static const List<String> flourishRefs = ['sax_c4', 'sax_e4', 'sax_g4'];

  /// Bumped on every new [playMotif] / [playFlourish] / [stop] call so a stale
  /// continuation from a previous call (e.g. a rapid replay, or disposal)
  /// aborts instead of interleaving notes.
  int _generation = 0;

  Timer? _timer;
  void Function()? _releaseWait;

  /// A cancellable delay. If [stop] (or a newer call) fires first, the returned
  /// future still completes — the caller then sees a generation mismatch and
  /// bails — but no timer is left pending.
  Future<void> _wait(Duration duration) {
    _cancelWait();
    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    _releaseWait = finish;
    _timer = Timer(duration, () {
      _timer = null;
      _releaseWait = null;
      finish();
    });
    return completer.future;
  }

  void _cancelWait() {
    _timer?.cancel();
    _timer = null;
    _releaseWait?.call();
    _releaseWait = null;
  }

  /// Plays [motif] — one fire per event, each interrupting the previous one.
  ///
  /// Completes when the motif finishes. Rethrows an [AudioError] from any
  /// [AudioService.playSample] so the card can show its audio-error state.
  Future<void> playMotif(List<MotifEvent> motif) async {
    if (motif.isEmpty) {
      throw ArgumentError.value(motif, 'motif', 'need >= 1 event');
    }
    final generation = ++_generation;

    Object? failure;
    void fire(String ref) {
      _audio
          .playSample(ref)
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace _) => failure ??= error,
          );
    }

    for (var i = 0; i < motif.length; i++) {
      fire(motif[i].ref); // interrupts the previous event
      await _wait(motif[i].hold);
      if (generation != _generation) return;
      // The last event's failure is checked after the cut below, so a note that
      // rejects mid-ring still silences the player before it surfaces.
      if (i < motif.length - 1 && failure != null) throw failure!;
    }

    await _audio.stop(); // cut the last note
    // A playSample that rejects just after the last gap would otherwise be
    // swallowed — yield one turn so its onError runs, then re-check.
    await Future<void>.delayed(Duration.zero);
    if (generation != _generation) return;
    if (failure != null) throw failure!;
  }

  /// Plays the short celebratory flourish. Best-effort: a playback failure here
  /// is swallowed — the flourish is decoration, not part of the exercise.
  Future<void> playFlourish() async {
    final generation = ++_generation;
    for (final ref in flourishRefs) {
      _audio.playSample(ref).ignore();
      await _wait(flourishGap);
      if (generation != _generation) return;
    }
  }

  /// Silences any motif still playing and cancels the pending gap.
  Future<void> stop() {
    _generation++;
    _cancelWait();
    return _audio.stop();
  }
}
