import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers every "fake" row of the spec's I/O & edge-case matrix, the pure
/// `audioAssetKeyFor` map, the `SamplePlaybackFailed` value contract, and the
/// `audioServiceProvider` wiring (override + dispose propagation).
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
    });

    test('stop() while idle just increments stopCount and completes', () async {
      final fake = FakeAudioService();

      await fake.stop();
      await fake.stop();

      expect(fake.stopCount, 2);
    });

    test('playLatency is awaited before playSample completes', () async {
      final fake = FakeAudioService(playLatency: const Duration(seconds: 5));

      var completed = false;
      final future = fake.playSample('sax_c4').then((_) => completed = true);

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse, reason: 'still within playLatency');

      fake.playLatency = Duration.zero; // does not affect the in-flight call
      await future;
      expect(completed, isTrue);
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

    test('asserts on a token outside ^[a-z0-9_]+\$', () {
      expect(() => audioAssetKeyFor('sax c4'), throwsA(isA<AssertionError>()));
      expect(() => audioAssetKeyFor('../x'), throwsA(isA<AssertionError>()));
      expect(() => audioAssetKeyFor('SAX_C4'), throwsA(isA<AssertionError>()));
    });
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
    ProviderContainer containerWithSpy(_SpyAudioService spy) =>
        ProviderContainer(
          overrides: [
            audioServiceProvider.overrideWith((ref) {
              ref.onDispose(spy.dispose);
              return spy;
            }),
          ],
        );

    test('exposes an AudioService', () {
      final spy = _SpyAudioService();
      final container = containerWithSpy(spy);
      addTearDown(container.dispose);

      expect(container.read(audioServiceProvider), isA<AudioService>());
    });

    test('container.dispose() calls the service dispose exactly once, and '
        'a disposed service rejects further use', () async {
      final spy = _SpyAudioService();
      final container = containerWithSpy(spy);
      final sub = container.listen(
        audioServiceProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final service = sub.read();

      container.dispose();

      expect(spy.disposeCount, 1);
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

/// Instrumented [AudioService] — no `just_audio`, no platform. Mirrors the
/// post-dispose `StateError` contract so provider teardown can be asserted.
class _SpyAudioService implements AudioService {
  int disposeCount = 0;
  bool _disposed = false;
  final List<String> playedRefs = <String>[];

  @override
  Future<void> dispose() async {
    disposeCount++;
    _disposed = true;
  }

  @override
  Future<void> playSample(String ref) async {
    if (_disposed) throw StateError('used after dispose()');
    playedRefs.add(ref);
  }

  @override
  Future<void> stop() async {
    if (_disposed) throw StateError('used after dispose()');
  }
}
