/// `just_audio`-backed [AudioService].
///
/// The implementation class is library-private: the only public symbol is
/// [audioServiceProvider], re-exported by the module barrel. This file is the
/// single point in the codebase that imports `package:just_audio/…` — the
/// AR-6 gate (`tool/check_module_boundaries.dart` Rule 4) enforces that.
library;

import 'package:flutter/foundation.dart' show FlutterError;
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
    } catch (e) {
      // Translate real playback failures into a domain error. A *missing*
      // bundled asset comes back from `rootBundle` as a `FlutterError` (an
      // Error, not an Exception). Every other playback failure — a present but
      // corrupt or undecodable file, a platform-side failure — surfaces as an
      // Exception (`PlayerException`, `PlatformException`). Both classes are
      // playback failures. A genuine programming error (StateError, TypeError,
      // a failed assert) is not — rethrow it untouched.
      if (e is! Exception && e is! FlutterError) rethrow;
      // If setAsset succeeded but play() threw, the player still holds the
      // asset — best-effort reset before we hand back a domain error. Swallow
      // anything this throws (a FlutterError included): we are already
      // returning a domain error and must not let the reset replace it.
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
    // Best-effort: silencing is idempotent / a no-op when idle, and there is
    // no domain error for `stop`. A raw platform failure — an Exception such as
    // `PlatformException`, or a `FlutterError` — must not cross the module
    // boundary, so both are swallowed. A genuine programming error still
    // surfaces, same guard as `playSample`.
    try {
      await _player.stop();
    } catch (e) {
      if (e is! Exception && e is! FlutterError) rethrow;
      // Ignore — silencing failed, but there is no domain error for `stop`.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Best-effort resource release. An Exception or a FlutterError from the
    // plugin is swallowed so it does not escape `ref.onDispose` during
    // container teardown; a genuine programming error still surfaces (same
    // guard as `playSample` / `stop`).
    try {
      await _player.dispose();
    } catch (e) {
      if (e is! Exception && e is! FlutterError) rethrow;
      // Swallowed: teardown is best-effort.
    }
  }

  void _ensureAlive() {
    if (_disposed) {
      throw StateError('AudioService used after dispose()');
    }
  }
}
