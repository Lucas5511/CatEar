import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_test/flutter_test.dart';

/// The per-type motif contours (Story 1.5). These are pure functions over the
/// catalog's `audioSampleRefs`, so they can be checked without audio.
void main() {
  List<String> refsOf(List<MotifEvent> motif) =>
      motif.map((e) => e.ref).toList();

  group('interval', () {
    test('is the Story 1.4 contour, unchanged: r0, r1, r0 at 450/450/900', () {
      final motif = intervalMotif(['a', 'b']);
      expect(refsOf(motif), ['a', 'b', 'a']);
      expect(motif.map((e) => e.hold.inMilliseconds).toList(), [450, 450, 900]);
      expect(motifDuration(motif), const Duration(milliseconds: 1800));
    });

    test('a single ref repeats rather than collapsing the contour', () {
      expect(refsOf(intervalMotif(['a'])), ['a', 'a', 'a']);
    });
  });

  group('chord', () {
    test('is block -> arpeggio -> block off [block, root, third, fifth]', () {
      final motif = chordMotif(['blk', 'r', '3rd', '5th']);
      expect(refsOf(motif), ['blk', 'r', '3rd', '5th', 'blk']);
    });

    test('the block rings longer than the arpeggio notes', () {
      final motif = chordMotif(['blk', 'r', '3rd', '5th']);
      final arpeggio = motif.sublist(1, 4).map((e) => e.hold).toSet();
      expect(arpeggio.length, 1, reason: 'the arpeggio is evenly spaced');
      expect(motif.first.hold, greaterThan(arpeggio.single));
      expect(motif.last.hold, greaterThan(arpeggio.single));
    });

    test('degrades on short ref lists — never a RangeError mid-session', () {
      expect(refsOf(chordMotif(['blk', 'r'])), ['blk', 'r', 'blk']);
      // Nothing to arpeggiate: the block alone, not the block twice.
      expect(refsOf(chordMotif(['blk'])), ['blk']);
      expect(chordMotif(const []), isEmpty);
    });
  });

  group('scale', () {
    test('is one event per ref, in catalog order', () {
      const refs = ['1', '2', '3', '4', '5', '6', '7', '8'];
      expect(refsOf(scaleMotif(refs)), refs);
    });

    test('walks at 250-300 ms/note and lands inside 2.0-2.4 s', () {
      const refs = ['1', '2', '3', '4', '5', '6', '7', '8'];
      final motif = scaleMotif(refs);
      for (final event in motif.take(refs.length - 1)) {
        expect(event.hold.inMilliseconds, inInclusiveRange(250, 300));
      }
      // The last note resolves instead of being chopped at the walking gap.
      expect(motif.last.hold, greaterThan(motif.first.hold));
      expect(motifDuration(motif).inMilliseconds, inInclusiveRange(2000, 2400));
    });

    test('at the interval gap those 8 notes would drag past 3.5 s', () {
      // The reason the rhythm is per type at all (human decision, 2026-09-06).
      const refs = ['1', '2', '3', '4', '5', '6', '7', '8'];
      final atIntervalPace = sequenceMotif(
        refs,
        gap: intervalNoteGap,
        finalHold: intervalReturnHold,
      );
      expect(motifDuration(atIntervalPace).inMilliseconds, greaterThan(3500));
      expect(
        motifDuration(scaleMotif(refs)),
        lessThan(motifDuration(atIntervalPace)),
      );
    });

    test('a scale shorter than 8 notes is still every note it has', () {
      expect(refsOf(scaleMotif(['1', '2'])), ['1', '2']);
      expect(scaleMotif(const []), isEmpty);
    });
  });

  test('motifDuration sums the holds', () {
    expect(
      motifDuration(const [
        MotifEvent('a', Duration(milliseconds: 100)),
        MotifEvent('b', Duration(milliseconds: 250)),
      ]),
      const Duration(milliseconds: 350),
    );
    expect(motifDuration(const []), Duration.zero);
  });
}
