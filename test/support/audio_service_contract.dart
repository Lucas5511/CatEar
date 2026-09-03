/// The behaviour contract of [AudioService], run against BOTH implementations
/// from ONE source.
///
/// Why this file exists: until 2026-09-03 the fake and the real service were
/// covered by two *different* suites. `FakeAudioService` serialized overlapping
/// calls; `_JustAudioService` did not — so 213 green tests coexisted with an
/// exercise that played no audio at all, and the divergence only surfaced when
/// the Story 1.4 phrase player (which overlaps calls on purpose, to shorten
/// notes) broke the `e2e-android` job. A fake that is *stronger* than the real
/// implementation does not protect the contract, it manufactures green.
///
/// So: one parameterized suite, two call sites.
///   - `test/audio_service_test.dart` runs it against `FakeAudioService`
///     under `flutter test` (milliseconds, no platform).
///   - `integration_test/catear_e2e_test.dart` runs it against the real
///     `_JustAudioService` on a device/emulator.
/// A behaviour that only one of them satisfies is a red build on one side.
///
/// Everything here is expressed through the public [AudioService] interface
/// only — no fake bookkeeping (`playedRefs`, `interruptedRefs`, …), no
/// `just_audio` types. Implementation-specific assertions stay in their own
/// suite: the fake's recorder in `test/audio_service_test.dart`, the provider
/// wiring in whichever suite owns the container.
///
/// Plain `test()`, never `testWidgets()`: this suite awaits real wall-clock
/// delays to create overlap, and `testWidgets` runs under a fake clock in
/// `flutter test` (but a live one in `integration_test`) — the same body would
/// mean two different things on the two sides, which is the exact failure mode
/// this file exists to prevent.
library;

import 'package:catear/audio/audio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sample tokens that both implementations must be able to play. All four are
/// real `audioSampleRefs` of `catalog_v1.json`, so the real service finds a
/// bundled `.wav` for each.
const playableRefs = ['sax_c4', 'sax_d4', 'sax_e4', 'sax_g4'];

/// A token that is well-formed (`^[a-z0-9_]+$`, so `audioAssetKeyFor` accepts
/// it) but has no playable sample behind it.
///
/// For the real service that is literally true — no `sax_zz9.wav` is bundled,
/// and `setAsset` fails. The fake must be built with this ref in its
/// `unplayableRefs` so both sides answer the same question.
const unplayableRef = 'sax_zz9';

/// Runs the full [AudioService] contract against whatever [build] returns.
///
/// [build] must hand back a fresh, live service on every call and register its
/// own teardown (the real one keeps a `ProviderContainer` alive; the fake needs
/// nothing). The service must treat [unplayableRef] as unplayable and every
/// entry of [playableRefs] as playable.
///
/// [timeout] bounds each individual playback: a ~2.5 s sample completes well
/// inside the default, and an emulator whose audio sink never signals
/// end-of-stream fails the test instead of hanging the job.
///
/// [overlap] is how long a test waits before firing the next, overlapping call.
/// It must be shorter than a sample's duration on both sides — for the fake,
/// shorter than its `playLatency`.
void runAudioServiceContract({
  required String target,
  required AudioService Function() build,
  Duration timeout = const Duration(seconds: 15),
  Duration overlap = const Duration(milliseconds: 30),
}) {
  group('AudioService contract — $target', () {
    late AudioService service;

    setUp(() {
      service = build();
    });

    test('plays a bundled sample, and replays it', () async {
      await service.playSample(playableRefs.first).timeout(timeout);
      // Replay is free: a second call for the same ref interrupts nothing that
      // is still playing and completes on its own.
      await service.playSample(playableRefs.first).timeout(timeout);
    });

    test('an unplayable ref fails as SamplePlaybackFailed, and the service '
        'survives it', () async {
      await expectLater(
        service.playSample(unplayableRef).timeout(timeout),
        throwsA(
          isA<SamplePlaybackFailed>()
              .having((e) => e.ref, 'ref', unplayableRef)
              .having((e) => e, 'is AudioError', isA<AudioError>()),
        ),
      );

      // A handled failure must not wedge the service.
      await service.playSample(playableRefs[1]).timeout(timeout);
    });

    test('overlapping playSample calls all complete, with no spurious '
        'error', () async {
      // This is the case that was green on the fake and broken on the real
      // service. The phrase player fires the next note before the previous one
      // finished; an unserialized implementation races `setAsset`/`play` on one
      // player and reports the aborted load as a playback failure.
      final first = service.playSample(playableRefs[0]);
      await Future<void>.delayed(overlap);
      final second = service.playSample(playableRefs[1]);
      await Future<void>.delayed(overlap);
      final third = service.playSample(playableRefs[2]);

      await Future.wait([first, second, third]).timeout(timeout);

      // Still usable afterwards.
      await service.playSample(playableRefs[3]).timeout(timeout);
    });

    test('a failing sample still reports failure while another call is in '
        'flight', () async {
      // Both halves of the contract at once. Interruption must be recognised
      // for what it is — never as "a newer call superseded me", which would
      // swallow a real failure that lands late and leave the card silent with
      // no error and no banner.
      final playing = service.playSample(playableRefs.first);
      await Future<void>.delayed(overlap);
      final missing = service.playSample(unplayableRef);

      await expectLater(
        missing.timeout(timeout),
        throwsA(
          isA<SamplePlaybackFailed>().having(
            (e) => e.ref,
            'ref',
            unplayableRef,
          ),
        ),
      );
      // The sample it cut short (or ran alongside) completes quietly either way.
      await playing.timeout(timeout);
    });

    test('stop() while idle completes', () async {
      await service.stop().timeout(timeout);
      await service.stop().timeout(timeout);
    });

    test('stop() during playback completes both futures, without an '
        'error', () async {
      final playing = service.playSample(playableRefs.first);
      await Future<void>.delayed(overlap);

      await service.stop().timeout(timeout);
      // The interrupted playback resolves — interruption is not failure.
      await playing.timeout(timeout);
    });

    test(
      'after dispose(), playSample and stop reject with StateError',
      () async {
        await service.dispose();

        await expectLater(
          service.playSample(playableRefs.first),
          throwsA(isA<StateError>()),
        );
        await expectLater(service.stop(), throwsA(isA<StateError>()));
      },
    );
  });
}
