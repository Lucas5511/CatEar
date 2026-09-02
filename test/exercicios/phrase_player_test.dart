import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
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
  test('plays the motif r0, r1, r0 with gaps', () {
    fakeAsync((async) {
      final fake = FakeAudioService();
      final player = PhrasePlayer(fake);

      player.playMotif(['sax_c4', 'sax_g4']);
      async.elapse(const Duration(seconds: 3));

      expect(fake.playedRefs, ['sax_c4', 'sax_g4', 'sax_c4']);
    });
  });

  test('single-note refs still yields a 3-event motif', () {
    fakeAsync((async) {
      final fake = FakeAudioService();
      PhrasePlayer(fake).playMotif(['sax_c4']);
      async.elapse(const Duration(seconds: 3));
      expect(fake.playedRefs, ['sax_c4', 'sax_c4', 'sax_c4']);
    });
  });

  test('each event interrupts the previous one (playLatency > 0)', () {
    fakeAsync((async) {
      final fake = FakeAudioService(playLatency: const Duration(seconds: 5));
      final player = PhrasePlayer(fake);

      player.playMotif(['sax_c4', 'sax_g4']);
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
            .playMotif(['sax_c4', 'sax_g4'])
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
          .playMotif(['sax_c4', 'sax_g4'])
          .catchError((Object e) => caught = e);

      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();

      expect(caught, isA<SamplePlaybackFailed>());
    });
  });

  test('empty refs fails with ArgumentError, not an assertion', () async {
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
