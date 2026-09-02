import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers every "fake" row of the spec's I/O & edge-case matrix, the pure
/// `audioAssetKeyFor` map (including against the real catalog tokens), the
/// `SamplePlaybackFailed` value contract, and the `audioServiceProvider` wiring
/// (override + dispose propagation).
///
/// The real `_JustAudioService` is never constructed here — the spec forbids
/// exercising it against `just_audio` under `flutter test`; a post-1.3b
/// integration test covers it (see `deferred-work.md`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FakeAudioService', () {
    test('playSample records the ref, in order (replay is free)', () async {
      final fake = FakeAudioService();

      await fake.playSample('sax_c4');
      await fake.playSample('sax_c4');
      await fake.playSample('sax_d4');

      expect(fake.playedRefs, ['sax_c4', 'sax_c4', 'sax_d4']);
      expect(fake.interruptedRefs, isEmpty, reason: 'zero-latency playback');
    });

    test('stop() while idle just increments stopCount and completes', () async {
      final fake = FakeAudioService();

      await fake.stop();
      await fake.stop();

      expect(fake.stopCount, 2);
    });

    test('playLatency keeps playSample pending until it elapses', () {
      fakeAsync((async) {
        final fake = FakeAudioService(playLatency: const Duration(seconds: 5));

        var completed = false;
        fake.playSample('sax_c4').then((_) => completed = true);

        async.elapse(const Duration(seconds: 4));
        expect(fake.isPlaying, isTrue);
        expect(completed, isFalse, reason: 'still within playLatency');

        async.elapse(const Duration(seconds: 1));
        expect(completed, isTrue);
        expect(fake.isPlaying, isFalse);
        expect(fake.interruptedRefs, isEmpty, reason: 'it finished on its own');
      });
    });

    test('a following playSample interrupts the one still playing', () {
      fakeAsync((async) {
        final fake = FakeAudioService(playLatency: const Duration(seconds: 5));

        var firstCompleted = false;
        fake.playSample('sax_c4').then((_) => firstCompleted = true);
        async.elapse(const Duration(seconds: 1));

        fake.playSample('sax_d4'); // cuts the first one short
        async.flushMicrotasks();

        expect(
          firstCompleted,
          isTrue,
          reason: 'interrupted call still resolves',
        );
        expect(fake.interruptedRefs, ['sax_c4']);
        expect(fake.playedRefs, ['sax_c4', 'sax_d4']);
        expect(fake.isPlaying, isTrue, reason: 'the second sample is playing');
      });
    });

    test('stop() interrupts the sample still playing', () {
      fakeAsync((async) {
        final fake = FakeAudioService(playLatency: const Duration(seconds: 5));

        var completed = false;
        fake.playSample('sax_c4').then((_) => completed = true);
        async.elapse(const Duration(seconds: 1));

        fake.stop();
        async.flushMicrotasks();

        expect(completed, isTrue);
        expect(fake.stopCount, 1);
        expect(fake.interruptedRefs, ['sax_c4']);
        expect(fake.isPlaying, isFalse);
      });
    });

    test(
      'a ref in unplayableRefs fails with SamplePlaybackFailed(ref)',
      () async {
        final fake = FakeAudioService(unplayableRefs: {'sax_missing'});

        await expectLater(
          fake.playSample('sax_missing'),
          throwsA(
            isA<SamplePlaybackFailed>().having(
              (e) => e.ref,
              'ref',
              'sax_missing',
            ),
          ),
        );
        expect(fake.playedRefs, isEmpty);
      },
    );

    test('unplayableRefs is mutable after construction', () async {
      final fake = FakeAudioService();
      fake.unplayableRefs.add('sax_c4');

      await expectLater(
        fake.playSample('sax_c4'),
        throwsA(isA<SamplePlaybackFailed>()),
      );

      fake.unplayableRefs.remove('sax_c4');
      await fake.playSample('sax_c4');
      expect(fake.playedRefs, ['sax_c4']);
    });

    test('playSample / stop after dispose throw StateError', () async {
      final fake = FakeAudioService();
      await fake.dispose();

      expect(fake.disposed, isTrue);
      expect(fake.disposeCount, 1);
      await expectLater(fake.playSample('sax_c4'), throwsA(isA<StateError>()));
      await expectLater(fake.stop(), throwsA(isA<StateError>()));
      expect(fake.playedRefs, isEmpty);
    });
  });

  group('audioAssetKeyFor', () {
    test('maps a token to assets/audio/<token>.wav', () {
      expect(audioAssetKeyFor('sax_db4'), 'assets/audio/sax_db4.wav');
      expect(audioAssetKeyFor('sax_c4'), 'assets/audio/sax_c4.wav');
    });

    test('throws ArgumentError on a token outside ^[a-z0-9_]+\$', () {
      expect(() => audioAssetKeyFor('sax c4'), throwsA(isA<ArgumentError>()));
      expect(() => audioAssetKeyFor('../x'), throwsA(isA<ArgumentError>()));
      expect(() => audioAssetKeyFor('SAX_C4'), throwsA(isA<ArgumentError>()));
      expect(() => audioAssetKeyFor(''), throwsA(isA<ArgumentError>()));
    });

    test(
      'every audioSampleRef in the real catalog maps to a well-formed key',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final curriculum = await container
            .read(curriculoRepositoryProvider)
            .load();

        final refs = {
          for (final stage in curriculum.stages)
            for (final exercise in stage.exercises) ...exercise.audioSampleRefs,
        };
        expect(
          refs,
          isNotEmpty,
          reason: 'the catalog references audio samples',
        );

        for (final ref in refs) {
          expect(
            audioAssetKeyFor(ref),
            matches(r'^assets/audio/[a-z0-9_]+\.wav$'),
            reason: 'catalog ref "$ref" must produce a valid bundle key',
          );
          expect(audioAssetKeyFor(ref), 'assets/audio/$ref.wav');
        }
      },
    );
  });

  group('SamplePlaybackFailed value contract', () {
    test('== / hashCode keyed on (ref, message); toString format', () {
      const a = SamplePlaybackFailed('sax_c4', 'boom');
      const b = SamplePlaybackFailed('sax_c4', 'boom');
      const otherRef = SamplePlaybackFailed('sax_d4', 'boom');
      const otherMsg = SamplePlaybackFailed('sax_c4', 'bang');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(otherRef)));
      expect(a, isNot(equals(otherMsg)));
      expect(a, isA<AudioError>());
      expect(a.toString(), 'AudioError.samplePlaybackFailed: sax_c4 — boom');
    });
  });

  group('audioServiceProvider', () {
    ProviderContainer containerWith(FakeAudioService fake) => ProviderContainer(
      overrides: [
        audioServiceProvider.overrideWith((ref) {
          ref.onDispose(fake.dispose);
          return fake;
        }),
      ],
    );

    test('exposes an AudioService', () {
      final fake = FakeAudioService();
      final container = containerWith(fake);
      addTearDown(container.dispose);

      expect(container.read(audioServiceProvider), isA<AudioService>());
    });

    test('container.dispose() calls the service dispose exactly once, and '
        'a disposed service rejects further use', () async {
      final fake = FakeAudioService();
      final container = containerWith(fake);
      // Hold a subscription so the auto-dispose provider is not torn down
      // before we dispose the container ourselves.
      final sub = container.listen(
        audioServiceProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final service = sub.read();

      container.dispose();

      expect(fake.disposeCount, 1);
      await expectLater(
        service.playSample('sax_c4'),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'overrideWithValue: consumers get the fake, no platform code',
      () async {
        final fake = FakeAudioService();
        final container = ProviderContainer(
          overrides: [audioServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final service = container.read(audioServiceProvider);
        expect(identical(service, fake), isTrue);

        await service.playSample('sax_c4');
        await service.stop();

        expect(fake.playedRefs, ['sax_c4']);
        expect(fake.stopCount, 1);
      },
    );
  });
}
