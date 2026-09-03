/// `just_audio`-backed [AudioService].
///
/// The implementation class is library-private: the only public symbol is
/// [audioServiceProvider], re-exported by the module barrel. This file is the
/// single point in the codebase that imports `package:just_audio/…` — the
/// AR-6 gate (`tool/check_module_boundaries.dart` Rule 4) enforces that.
library;

import 'dart:async';

import 'package:audio_session/audio_session.dart';
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
  _JustAudioService() : _sessionReady = _configureSession();

  final AudioPlayer _player = AudioPlayer();
  bool _disposed = false;

  /// Completes once the platform audio session has been configured (or once
  /// configuring it has failed — see [_configureSession]). Awaited before the
  /// first `play()`.
  ///
  /// iOS will not play through a session whose category was never set: the
  /// notes come out silent, or duck/mix against whatever else is playing.
  /// Android does not need this, which is exactly why it went unnoticed —
  /// `e2e-android` is green either way, and no CI job can see the iOS half.
  final Future<void> _sessionReady;

  /// Declares this app as a music player to the platform: playback continues
  /// with the silent switch on (an ear-training app that goes quiet when the
  /// phone is on silent is broken), and it takes the audio focus rather than
  /// ducking under it — a training sample the learner has to identify must not
  /// be mixed with anything.
  ///
  /// Best-effort, and deliberately non-fatal: a session failure must not turn
  /// into a playback error on Android, which needs none of this. Same guard as
  /// [_quietStop] / [dispose] — a genuine programming error still surfaces.
  static Future<void> _configureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      if (e is! Exception && e is! FlutterError) rethrow;
      // Swallowed: playback is still attempted. On Android it will work
      // anyway; on iOS the failure shows up as silence, which is the state we
      // were already in before this call existed.
    }
  }

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

  /// How long a new operation waits for its predecessor before abandoning it.
  ///
  /// `just_audio`'s `play()` awaits a completer the platform may never settle
  /// (an emulator audio sink that never signals end-of-stream). Without this
  /// bound one wedged operation would block every later `playSample` / `stop`
  /// for the life of the service. The stalled op still drops out on its own
  /// generation check when (if) it resolves.
  static const _predecessorWait = Duration(seconds: 10);

  @override
  // `async` so a post-dispose `_ensureAlive()` surfaces as a rejected future,
  // not a synchronous throw — callers (the phrase player, widget `dispose`)
  // handle it as an error on the returned future.
  Future<void> playSample(String ref) async {
    _ensureAlive();
    final generation = ++_generation;
    // Preempt first, outside the chain, so an in-flight `play()` completes and
    // its operation drops out at its next generation check.
    final preempted = _guarded(_quietStop());
    final op = _waitForPredecessor()
        .then((_) => preempted)
        .then((_) => _playSerialized(ref, generation));
    _chain = op.then((_) {}, onError: (Object _, StackTrace _) {});
    return op;
  }

  /// The current chain, bounded by [_predecessorWait] so a wedged operation
  /// cannot block the queue forever.
  Future<void> _waitForPredecessor() =>
      _chain.timeout(_predecessorWait, onTimeout: () {});

  /// Attaches an error listener now so a rejection in the window before the
  /// chain reaches this future is not delivered to the zone as an unhandled
  /// async error. The original future is still awaited by the chain, so the
  /// error is not lost — only pre-observed.
  Future<void> _guarded(Future<void> future) {
    unawaited(future.catchError((Object _) {}));
    return future;
  }

  Future<void> _playSerialized(String ref, int generation) async {
    if (_disposed || generation != _generation) return;
    // Cheap after the first call — the future is already complete.
    await _sessionReady;
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
      // Interruption is not failure. A newer `playSample`/`stop` preempts us by
      // stopping the player, and `just_audio` aborts the in-flight load with
      // `PlayerInterruptedException` — exactly what the interface promises
      // ("interrupts any sample still playing"), and what the Story 1.4 phrase
      // player triggers on every note it cuts short.
      //
      // Matched on the exception type, NOT on a stale generation: a superseded
      // call can still fail for a real reason (a missing or corrupt sample
      // whose `setAsset` outlives the 450 ms note gap), and swallowing that
      // would leave the card silent with no error and no banner.
      if (e is PlayerInterruptedException) return;
      if (_disposed) return;
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
    // Supersede whatever is in flight and silence the player immediately,
    // outside the chain. `stop` deliberately does NOT wait for the queue:
    // silencing must stay responsive even when a predecessor is wedged, and
    // the superseded operation abandons itself on its own generation check.
    ++_generation;
    return _quietStop();
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
