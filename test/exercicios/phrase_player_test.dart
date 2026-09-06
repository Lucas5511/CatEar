import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/exercicios/presentation/phrase_player.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// An [AudioService] whose Nth `playSample` rejects [after] a delay, to model a
/// note that starts fine and fails mid-playback.
class _LateFailAudio implements AudioService {
  _LateFailAudio({required this.failOnCall, required this.after});

  final int failOnCall;
  final Duration after;
  final List<String> played = <String>[];
  int _calls = 0;

  @override
  Future<void> playSample(String ref) {
    _calls++;
    played.add(ref);
    if (_calls == failOnCall) {
      return Future<void>.delayed(
        after,
        () => throw AudioError.samplePlaybackFailed(ref, 'late failure'),
      );
    }
    return Future<void>.value();
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  test('plays whatever sequence it is handed — interval: r0, r1, r0', () {
    fakeAsync((async) {
      final fake = FakeAudioService();
      final player = PhrasePlayer(fake);

      player.playMotif(intervalMotif(['sax_c4', 'sax_g4']));
      async.elapse(const Duration(seconds: 3));

      expect(fake.playedRefs, ['sax_c4', 'sax_g4', 'sax_c4']);
    });
  });

  test('single-note refs still yields a 3-event interval motif', () {
    fakeAsync((async) {
      final fake = FakeAudioService();
      PhrasePlayer(fake).playMotif(intervalMotif(['sax_c4']));
      async.elapse(const Duration(seconds: 3));
      expect(fake.playedRefs, ['sax_c4', 'sax_c4', 'sax_c4']);
    });
  });

  test('a chord is 5 events: block, arpeggio, block', () {
    fakeAsync((async) {
      final fake = FakeAudioService();
      PhrasePlayer(fake)
          .playMotif(chordMotif(['sax_maj_c4', 'sax_c4', 'sax_e4', 'sax_g4']));
      async.elapse(const Duration(seconds: 5));
      expect(fake.playedRefs, [
        'sax_maj_c4',
        'sax_c4',
        'sax_e4',
        'sax_g4',
        'sax_maj_c4',
      ]);
    });
  });

  test('a scale is one event per ref, in order', () {
    fakeAsync((async) {
      final fake = FakeAudioService();
      const refs = [
        'sax_c4', 'sax_d4', 'sax_e4', 'sax_f4', //
        'sax_g4', 'sax_a4', 'sax_b4', 'sax_c5',
      ];
      PhrasePlayer(fake).playMotif(scaleMotif(refs));
      async.elapse(const Duration(seconds: 5));
      expect(fake.playedRefs, refs);
    });
  });

  test('a short chord ref list degrades instead of throwing', () {
    // Never a RangeError mid-session: a catalog that ships fewer refs than the
    // positional contract promises still plays what there is.
    fakeAsync((async) {
      final fake = FakeAudioService();
      PhrasePlayer(fake).playMotif(chordMotif(['sax_maj_c4', 'sax_c4']));
      async.elapse(const Duration(seconds: 5));
      expect(fake.playedRefs, ['sax_maj_c4', 'sax_c4', 'sax_maj_c4']);
    });

    fakeAsync((async) {
      final fake = FakeAudioService();
      PhrasePlayer(fake).playMotif(chordMotif(['sax_maj_c4']));
      async.elapse(const Duration(seconds: 5));
      expect(fake.playedRefs, ['sax_maj_c4']);
    });

    expect(chordMotif(const []), isEmpty);
    expect(intervalMotif(const []), isEmpty);
    expect(scaleMotif(const []), isEmpty);
  });

  test('the gaps come from the events, not from the player', () {
    fakeAsync((async) {
      final fake = FakeAudioService();
      PhrasePlayer(fake).playMotif(const [
        MotifEvent('sax_c4', Duration(milliseconds: 100)),
        MotifEvent('sax_g4', Duration(milliseconds: 100)),
      ]);
      async.elapse(const Duration(milliseconds: 150));
      expect(fake.playedRefs, ['sax_c4', 'sax_g4']);
      expect(fake.stopCount, 0, reason: 'the last note is still ringing');
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
      expect(fake.stopCount, greaterThanOrEqualTo(1));
    });
  });

  test('each event interrupts the previous one (playLatency > 0)', () {
    fakeAsync((async) {
      final fake = FakeAudioService(playLatency: const Duration(seconds: 5));
      final player = PhrasePlayer(fake);

      player.playMotif(intervalMotif(['sax_c4', 'sax_g4']));
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();

      // r0 cut by r1, r1 cut by r0, the returning r0 cut by the final stop().
      expect(fake.interruptedRefs, ['sax_c4', 'sax_g4', 'sax_c4']);
      expect(fake.stopCount, greaterThanOrEqualTo(1));
    });
  });

  test(
    'a SamplePlaybackFailed from playSample propagates out of playMotif',
    () {
      fakeAsync((async) {
        final fake = FakeAudioService(unplayableRefs: {'sax_c4'});
        Object? caught;
        PhrasePlayer(fake)
            .playMotif(intervalMotif(['sax_c4', 'sax_g4']))
            .catchError((Object e) => caught = e);

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(caught, isA<SamplePlaybackFailed>());
      });
    },
  );

  test('a playSample that rejects mid-note still fails playMotif', () {
    fakeAsync((async) {
      // The returning note (3rd fire) starts fine, then fails 400 ms in.
      final audio = _LateFailAudio(
        failOnCall: 3,
        after: const Duration(milliseconds: 400),
      );
      Object? caught;
      PhrasePlayer(audio)
          .playMotif(intervalMotif(['sax_c4', 'sax_g4']))
          .catchError((Object e) => caught = e);

      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();

      expect(caught, isA<SamplePlaybackFailed>());
    });
  });

  test('an empty motif fails with ArgumentError, not an assertion', () async {
    final fake = FakeAudioService();
    await expectLater(
      PhrasePlayer(fake).playMotif(const []),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('the flourish plays sax_c4 -> sax_e4 -> sax_g4', () {
    fakeAsync((async) {
      final fake = FakeAudioService();
      PhrasePlayer(fake).playFlourish();
      async.elapse(const Duration(seconds: 2));
      expect(fake.playedRefs, ['sax_c4', 'sax_e4', 'sax_g4']);
    });
  });
}
