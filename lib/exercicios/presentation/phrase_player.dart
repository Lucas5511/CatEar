/// Sequences [AudioService.playSample] into a short melodic motif so an
/// interval is always heard *in context* (FR-2 / AC2), never as two isolated
/// notes in silence.
///
/// The catalog gives exactly two notes per interval (`refs[0]`, `refs[1]`,
/// already ordered by `direction`). The smallest honest musical context within
/// the 14 v1 samples is a 3-event contour reusing those notes — `r0, r1, r0` —
/// with rhythm. `playSample` interrupts whatever is playing and completes on
/// interruption, so the player fires each note without waiting for the whole
/// sample and uses timed gaps between fires; the last note rings out for
/// [returnHold] and is then cut with `stop()`.
///
/// Rhythm default (Design Notes): ~450 ms between the first two events, ~900 ms
/// hold on the returning note. Orchestration lives here in `exercicios/`, never
/// inside `audio/`.
library;

import 'dart:async';

import 'package:catear/audio/audio.dart';

/// Plays the interval motif for one exercise. One instance per screen; reused
/// for replays (NFR-5 — no limit, no penalty).
class PhrasePlayer {
  PhrasePlayer(
    this._audio, {
    this.noteGap = const Duration(milliseconds: 450),
    this.returnHold = const Duration(milliseconds: 900),
    this.flourishGap = const Duration(milliseconds: 170),
  });

  final AudioService _audio;

  /// Gap after each of the first two motif events before the next fires.
  final Duration noteGap;

  /// How long the returning note rings before it is cut.
  final Duration returnHold;

  /// Gap between the notes of the correct-answer flourish.
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

  /// Plays the `r0, r1, r0` motif for [audioSampleRefs].
  ///
  /// Completes when the motif finishes. Rethrows an [AudioError] from any
  /// [AudioService.playSample] so the card can show its audio-error state.
  Future<void> playMotif(List<String> audioSampleRefs) async {
    if (audioSampleRefs.isEmpty) {
      throw ArgumentError.value(
        audioSampleRefs,
        'audioSampleRefs',
        'need >= 1 ref',
      );
    }
    final generation = ++_generation;
    final r0 = audioSampleRefs.first;
    final r1 = audioSampleRefs.length > 1 ? audioSampleRefs[1] : r0;

    Object? failure;
    void fire(String ref) {
      _audio
          .playSample(ref)
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace _) => failure ??= error,
          );
    }

    fire(r0);
    await _wait(noteGap);
    if (generation != _generation) return;
    if (failure != null) throw failure!;

    fire(r1); // interrupts r0
    await _wait(noteGap);
    if (generation != _generation) return;
    if (failure != null) throw failure!;

    fire(r0); // interrupts r1
    await _wait(returnHold);
    if (generation != _generation) return;
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
