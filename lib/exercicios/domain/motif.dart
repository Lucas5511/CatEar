/// The musical shape a question is heard as, expressed as **data**.
///
/// Story 1.4 hard-coded a 3-event contour (`r0, r1, r0`) inside `PhrasePlayer`.
/// That works for an interval and only for an interval: it truncates the 8
/// notes of a scale to two and collapses a triad to its block. Story 1.5 moves
/// the contour out of the player and onto the [ExerciseQuestion], built here in
/// `domain/` by the per-type branches of `questionFor`.
///
/// Why data and not a `switch` in the player: `check_module_boundaries` Rule 6
/// cannot catch a branch on `ExerciseType` inside `lib/exercicios/presentation/`
/// (the type is named legitimately there), so "no per-type code in the
/// presentation flow" has to be a design property. Keeping the contour — and
/// its rhythm — on the question is what makes the player a dumb executor.
///
/// **Rhythm is per type** (human decision, 2026-09-06), not one global
/// `noteGap`: a scale at 450 ms/note drags for 3.6 s and stops being heard as a
/// scale, while a chord wants its block to ring longer than the arpeggio notes.
library;

import 'package:flutter/foundation.dart';

/// One sample fire plus how long it is allowed to ring before the next event
/// interrupts it (or, for the last event, before the motif is cut).
///
/// `AudioService.playSample` interrupts whatever is playing and completes on
/// interruption, so [hold] is a *gap between fires*, not a sample length.
@immutable
class MotifEvent {
  const MotifEvent(this.ref, this.hold);

  /// Opaque sample token, straight from `Exercise.audioSampleRefs`.
  final String ref;

  /// Time from this fire to the next one.
  final Duration hold;

  @override
  bool operator ==(Object other) =>
      other is MotifEvent && other.ref == ref && other.hold == hold;

  @override
  int get hashCode => Object.hash(ref, hold);

  @override
  String toString() => 'MotifEvent($ref, ${hold.inMilliseconds}ms)';
}

/// Interval rhythm — unchanged from Story 1.4: 450 / 450 / 900 ms.
const Duration intervalNoteGap = Duration(milliseconds: 450);

/// How long the returning note of an interval rings before it is cut.
const Duration intervalReturnHold = Duration(milliseconds: 900);

/// How long the opening block of a chord rings before the arpeggio starts.
/// Longer than [chordArpeggioGap] so the ear hears "one sound, then its notes".
const Duration chordBlockHold = Duration(milliseconds: 700);

/// Gap between the arpeggio notes of a chord (root, third, fifth).
const Duration chordArpeggioGap = Duration(milliseconds: 260);

/// How long the closing block of a chord rings before it is cut.
const Duration chordFinalBlockHold = Duration(milliseconds: 900);

/// Gap between the notes of a scale. Inside the ~250–300 ms/note the frozen
/// block calls for: 8 notes land at ~2.3 s, which still reads as a scale.
const Duration scaleNoteGap = Duration(milliseconds: 270);

/// How long the last note of a scale rings before it is cut — a little longer
/// than [scaleNoteGap] so the run resolves instead of being chopped.
const Duration scaleFinalHold = Duration(milliseconds: 450);

/// `r0, r1, r0` — the Story 1.4 contour, byte-identical.
///
/// A single ref still yields 3 events (the same note three times), which is the
/// behaviour Story 1.4 shipped and its tests freeze.
List<MotifEvent> intervalMotif(List<String> refs) {
  if (refs.isEmpty) return const [];
  final r0 = refs.first;
  final r1 = refs.length > 1 ? refs[1] : r0;
  return [
    MotifEvent(r0, intervalNoteGap),
    MotifEvent(r1, intervalNoteGap),
    MotifEvent(r0, intervalReturnHold),
  ];
}

/// Block → arpeggio → block, from `[block, root, third, fifth]`.
///
/// Story 1.4b stored `audioSampleRefs` in exactly that positional order for
/// this contour (see `Exercise.audioSampleRefs`). With the v1 catalog that is 5
/// events; the code degrades instead of throwing if a future catalog ships
/// fewer refs, because a `RangeError` mid-session would take the screen down.
List<MotifEvent> chordMotif(List<String> refs) {
  if (refs.isEmpty) return const [];
  final block = refs.first;
  final arpeggio = refs.skip(1).toList();
  // Nothing to arpeggiate: play the block alone rather than twice in a row.
  if (arpeggio.isEmpty) return [MotifEvent(block, chordFinalBlockHold)];
  return [
    MotifEvent(block, chordBlockHold),
    for (final ref in arpeggio) MotifEvent(ref, chordArpeggioGap),
    MotifEvent(block, chordFinalBlockHold),
  ];
}

/// Every ref in order, one event each — the 8 notes of a scale as written in
/// the catalog (`direction` is already applied to the refs).
List<MotifEvent> scaleMotif(List<String> refs) =>
    sequenceMotif(refs, gap: scaleNoteGap, finalHold: scaleFinalHold);

/// The generic "play the refs in order" contour.
List<MotifEvent> sequenceMotif(
  List<String> refs, {
  required Duration gap,
  required Duration finalHold,
}) => [
  for (var i = 0; i < refs.length; i++)
    MotifEvent(refs[i], i == refs.length - 1 ? finalHold : gap),
];

/// Total wall time of [motif] — the sum of the holds. Used by tests to advance
/// a fake clock past a playback without hard-coding a per-type number.
Duration motifDuration(Iterable<MotifEvent> motif) =>
    motif.fold(Duration.zero, (total, event) => total + event.hold);
