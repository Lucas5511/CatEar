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

  /// Bumped by every [playSample] / [stop] / [dispose]. An operation whose
  /// generation is stale was superseded mid-flight and abandons its remaining
  /// steps instead of mutating a player that now belongs to a newer call.
  int _generation = 0;

  /// Serializes the player mutations (`setAsset` / `play`). The first real
  /// consumer — the Story 1.4 phrase player — fires overlapping `playSample`
  /// calls on purpose to shorten notes, and two unserialized runs of
  /// `setAsset → play → stop` on one [AudioPlayer] interleave with undefined
  /// order (it surfaced as a `PlayerException` on a `-noaudio` emulator).
  /// `stop()` is the one call left outside the chain: it must be able to
  /// preempt an in-flight `play()` so its future completes.
  Future<void> _chain = Future<void>.value();

  @override
  // `async` so a post-dispose `_ensureAlive()` surfaces as a rejected future,
  // not a synchronous throw — callers (the phrase player, widget `dispose`)
  // handle it as an error on the returned future.
  Future<void> playSample(String ref) async {
    _ensureAlive();
    final generation = ++_generation;
    // Preempt first, outside the chain, so an in-flight `play()` completes and
    // its operation drops out at its next generation check.
    final preempted = _quietStop();
    final op = _chain
        .then((_) => preempted)
        .then((_) => _playSerialized(ref, generation));
    _chain = op.then((_) {}, onError: (Object _, StackTrace _) {});
    return op;
  }

  Future<void> _playSerialized(String ref, int generation) async {
    if (_disposed || generation != _generation) return;
    try {
      await _player.setAsset(audioAssetKeyFor(ref));
      if (_disposed || generation != _generation) return;
      // `just_audio`'s play() future completes when playback finishes (or is
      // stopped) — then stop() releases the decoders.
      await _player.play();
      if (_disposed || generation != _generation) return;
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
      // Superseded mid-flight: a newer `playSample`/`stop` preempted us and
      // `just_audio` aborted the load or the playback. That is *interruption*,
      // which the contract promises — not a playback failure. Reporting it
      // would make the phrase player of Story 1.4 (which shortens notes by
      // firing overlapping calls on purpose) see a spurious error on every
      // note it cuts.
      if (_disposed || generation != _generation) return;
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
  // `async` for the same reason as [playSample]: post-dispose use rejects the
  // returned future rather than throwing synchronously.
  Future<void> stop() async {
    _ensureAlive();
    // Supersede any playback in flight, then silence outside the chain so the
    // pending `play()` can complete; the returned future still waits for the
    // chain so callers observe a settled player.
    ++_generation;
    final stopped = _quietStop();
    final op = _chain.then((_) => stopped);
    _chain = op.then((_) {}, onError: (Object _, StackTrace _) {});
    return op;
  }

  /// Silences the player, swallowing platform failures. Best-effort: silencing
  /// is idempotent / a no-op when idle, and there is no domain error for
  /// `stop`. A raw `PlatformException` / `FlutterError` must not cross the
  /// module boundary; a genuine programming error still surfaces, same guard
  /// as [playSample].
  Future<void> _quietStop() async {
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
    ++_generation;
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
