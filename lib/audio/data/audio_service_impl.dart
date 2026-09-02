/// `just_audio`-backed [AudioService].
///
/// The implementation class is library-private: the only public symbol is
/// [audioServiceProvider], re-exported by the module barrel. This file is the
/// single point in the codebase that imports `package:just_audio/…` — the
/// AR-6 gate (`tool/check_module_boundaries.dart` Rule 4) enforces that.
library;

import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/audio_assets.dart';
import '../domain/audio_service.dart';

part 'audio_service_impl.g.dart';

/// Provides the audio service. Consumers depend only on this; tests override
/// it with a `FakeAudioService`.
@riverpod
AudioService audioService(Ref ref) {
  final service = _JustAudioService();
  ref.onDispose(service.dispose);
  return service;
}

/// Wraps a single [AudioPlayer]. Not unit-tested — it runs against the
/// platform; a post-1.3b integration test exercises it (see `deferred-work.md`).
class _JustAudioService implements AudioService {
  _JustAudioService();

  final AudioPlayer _player = AudioPlayer();
  bool _disposed = false;

  @override
  Future<void> playSample(String ref) async {
    _ensureAlive();
    try {
      await _player.stop();
      await _player.setAsset(audioAssetKeyFor(ref));
      // `just_audio`'s play() future completes when playback finishes (or is
      // stopped) — then stop() releases the decoders.
      await _player.play();
      await _player.stop();
    } on Exception catch (e) {
      // Only package/platform exceptions are translated. A programming error
      // (StateError, TypeError, a failed assert) is not a playback failure —
      // let it surface. `PlayerException` / `PlatformException` are Exceptions.
      // If setAsset succeeded but play() threw, the player still holds the
      // asset — best-effort reset before we hand back a domain error.
      try {
        await _player.stop();
      } catch (_) {
        // Already failing; nothing useful to do.
      }
      throw AudioError.samplePlaybackFailed(ref, e.toString());
    }
  }

  @override
  Future<void> stop() async {
    _ensureAlive();
    // Best-effort: a raw PlatformException from the plugin must not cross the
    // module boundary, and silencing is idempotent / no-op when idle.
    try {
      await _player.stop();
    } catch (_) {
      // Ignore — silencing failed, but there is no domain error for `stop`.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Swallow teardown failures so the exception does not escape from inside
    // `ref.onDispose` during container teardown.
    try {
      await _player.dispose();
    } catch (_) {
      // Best-effort resource release.
    }
  }

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('AudioService used after dispose()');
    }
  }
}
