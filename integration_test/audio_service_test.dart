// End-to-end tests for the real `_JustAudioService` (Story 1.3b).
//
// Story 1.3 deliberately never exercised the `just_audio`-backed implementation
// under `flutter test` (it needs a platform + bundled assets). This suite closes
// F2 of the Story 1.3 TEA review: it reads `audioServiceProvider` with NO
// override, so it gets the real instance, and drives it against the 14 `.wav`
// samples produced by this story.
//
// Runs in the `e2e-android` CI job (`flutter test integration_test` on an
// emulator). The emulator is booted WITH audio so playback actually runs.

import 'package:catear/audio/audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Hard ceiling on any single real playback call. A 2.5 s sample completes in
/// ~2.5 s; if the emulator's audio sink never signals completion the job should
/// fail fast here, not hang until the CI timeout.
const _playTimeout = Duration(seconds: 15);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A container whose `audioServiceProvider` is the real (unoverridden)
  /// service, kept alive by a live subscription so the auto-dispose provider is
  /// not torn down before the test drives it.
  ///
  /// Registers tear-downs for both the subscription and the container. The
  /// container tear-down is guarded so a test that disposes the container
  /// itself (or an `expect` that throws before it does) never leaks the
  /// underlying `AudioPlayer` platform resource.
  ({ProviderContainer container, AudioService service}) realService() {
    final container = ProviderContainer();
    final sub = container.listen(
      audioServiceProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(() {
      try {
        sub.close();
      } catch (_) {
        // Container already disposed — the subscription went with it.
      }
    });
    addTearDown(() {
      try {
        container.dispose();
      } on StateError {
        // A test disposed the container on purpose; a second call is a no-op.
      }
    });
    return (container: container, service: sub.read());
  }

  testWidgets('playSample of a bundled sample completes without error', (
    tester,
  ) async {
    final (container: _, :service) = realService();

    expect(service, isA<AudioService>());
    await service.playSample('sax_c4').timeout(_playTimeout);
    // A second call (replay) also completes — interrupts the previous one.
    await service.playSample('sax_c4').timeout(_playTimeout);
  });

  testWidgets(
    'playSample of a well-formed token with no asset -> SamplePlaybackFailed',
    (tester) async {
      final (container: _, :service) = realService();

      // `sax_zz9` matches ^[a-z0-9_]+$ so `audioAssetKeyFor` accepts it, but no
      // such file is bundled -> `setAsset` throws a FlutterError inside
      // `just_audio`. It must surface as a domain error, never a raw
      // FlutterError / PlayerException / PlatformException.
      await expectLater(
        service.playSample('sax_zz9').timeout(_playTimeout),
        throwsA(
          isA<SamplePlaybackFailed>()
              .having((e) => e.ref, 'ref', 'sax_zz9')
              .having((e) => e, 'is AudioError', isA<AudioError>()),
        ),
      );

      // The service is still usable after a handled failure.
      await service.playSample('sax_d4').timeout(_playTimeout);
    },
  );

  testWidgets(
    'overlapping playSample calls interrupt cleanly, without a spurious error',
    (tester) async {
      final (:container, :service) = realService();
      addTearDown(container.dispose);

      // The Story 1.4 phrase player shortens notes by firing the next sample
      // before the previous one finished — the interface promises "interrupts
      // any sample still playing". Fired faster than a load can complete, an
      // unserialized implementation races `setAsset`/`play` on one AudioPlayer
      // and reports the aborted load as `SamplePlaybackFailed`.
      final first = service.playSample('sax_c4');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final second = service.playSample('sax_e4');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final third = service.playSample('sax_g4');

      await Future.wait([first, second, third])
          .timeout(const Duration(seconds: 15));

      // Still usable afterwards.
      await service.playSample('sax_c4').timeout(const Duration(seconds: 15));
    },
  );

  testWidgets(
    'a missing sample still reports failure when other calls are in flight',
    (tester) async {
      final (container: _, :service) = realService();

      // Both halves of the contract at once. Interruption is matched on
      // `PlayerInterruptedException`, never on "a newer call superseded me" —
      // otherwise a real failure landing after supersession would be swallowed
      // and the card would go silent with no error and no banner.
      //
      // Start a real sample, then ask for a missing one while it plays:
      // - the missing request is current, so its failure must surface;
      // - the sample it cut short was interrupted, so it must complete quietly.
      final playing = service.playSample('sax_c4');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final missing = service.playSample('sax_zz9');

      await expectLater(
        missing.timeout(_playTimeout),
        throwsA(
          isA<SamplePlaybackFailed>().having((e) => e.ref, 'ref', 'sax_zz9'),
        ),
      );
      await playing.timeout(_playTimeout);
    },
  );

  testWidgets('disposing the container disposes the service, without throwing', (
    tester,
  ) async {
    final (:container, :service) = realService();

    await service.playSample('sax_g4').timeout(_playTimeout);

    // `audioServiceProvider` wires `ref.onDispose(service.dispose)`. The async
    // work of `_JustAudioService.dispose()` runs after this returns; the
    // post-dispose `StateError` assertions below are what prove it ran.
    container.dispose();

    await expectLater(service.playSample('sax_c4'), throwsA(isA<StateError>()));
    await expectLater(service.stop(), throwsA(isA<StateError>()));
  });
}
