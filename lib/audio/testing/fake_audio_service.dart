/// In-memory [AudioService] for tests. Zero dependency on `just_audio` or any
/// platform channel — injected via `audioServiceProvider.overrideWithValue`.
library;

import '../domain/audio_service.dart';

/// Records every call and simulates playback without producing sound.
///
/// Inspect [playedRefs] (in order), [stopCount] and [disposed]. Configure
/// [unplayableRefs] to make specific tokens fail with [SamplePlaybackFailed],
/// and [playLatency] to delay [playSample] completion.
class FakeAudioService implements AudioService {
  FakeAudioService({
    Set<String>? unplayableRefs,
    this.playLatency = Duration.zero,
  }) : unplayableRefs = unplayableRefs ?? <String>{};

  /// Refs recorded by [playSample], in call order. A failed playback is not
  /// recorded here.
  final List<String> playedRefs = <String>[];

  /// Number of [stop] calls.
  int stopCount = 0;

  /// Whether [dispose] has been called.
  bool disposed = false;

  /// Tokens that [playSample] must reject with [SamplePlaybackFailed].
  /// Mutable so a test can add/remove entries after construction.
  final Set<String> unplayableRefs;

  /// Awaited before [playSample] completes. Default [Duration.zero].
  Duration playLatency;

  @override
  Future<void> playSample(String ref) async {
    _ensureAlive();
    if (unplayableRefs.contains(ref)) {
      throw AudioError.samplePlaybackFailed(ref, 'ref marked unplayable');
    }
    playedRefs.add(ref);
    if (playLatency > Duration.zero) {
      await Future<void>.delayed(playLatency);
    }
  }

  @override
  Future<void> stop() async {
    _ensureAlive();
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  void _ensureAlive() {
    if (disposed) {
      throw StateError('FakeAudioService used after dispose()');
    }
  }
}
