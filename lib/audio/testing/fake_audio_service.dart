/// In-memory [AudioService] for tests. Zero dependency on `just_audio` or any
/// platform channel — injected via `audioServiceProvider.overrideWithValue`.
library;

import 'dart:async';

import '../domain/audio_service.dart';

/// Records every call and simulates playback without producing sound.
///
/// Inspect [playedRefs] (in order), [interruptedRefs], [stopCount],
/// [disposeCount] / [disposed] and [isPlaying]. Configure [unplayableRefs] to
/// make specific tokens fail with [SamplePlaybackFailed], and [playLatency] to
/// give playback a non-zero duration so interruption is observable.
class FakeAudioService implements AudioService {
  FakeAudioService({
    Set<String>? unplayableRefs,
    this.playLatency = Duration.zero,
  }) : unplayableRefs = unplayableRefs ?? <String>{};

  /// Refs recorded by [playSample], in call order. A failed playback is not
  /// recorded here.
  final List<String> playedRefs = <String>[];

  /// Refs whose playback was cut short — by a following [playSample] or by
  /// [stop] — before its [playLatency] elapsed. Empty when [playLatency] is
  /// zero (playback completes synchronously, nothing to interrupt).
  final List<String> interruptedRefs = <String>[];

  /// Number of [stop] calls.
  int stopCount = 0;

  /// Number of [dispose] calls. `1` after a normal provider teardown.
  int disposeCount = 0;

  /// Whether [dispose] has been called at least once.
  bool get disposed => disposeCount > 0;

  /// Tokens that [playSample] must reject with [SamplePlaybackFailed].
  /// Mutable so a test can add/remove entries after construction.
  final Set<String> unplayableRefs;

  /// How long a [playSample] call stays "playing" before completing. Default
  /// [Duration.zero] — playback completes on the next microtask and cannot be
  /// interrupted. A non-zero value lets a test observe interruption.
  Duration playLatency;

  Completer<void>? _inFlight;
  String? _playingRef;

  /// The pending completion of the sample in flight. A [Timer] (not a
  /// `Future.delayed`) so interruption can cancel it: a `Future.delayed` left
  /// running keeps a pending timer alive past the end of the test that started
  /// it, which trips `testWidgets`' timer check in any suite that interrupts
  /// playback.
  Timer? _timer;

  /// Whether a [playSample] call is currently mid-playback (only possible with
  /// a non-zero [playLatency]).
  bool get isPlaying => _playingRef != null;

  @override
  Future<void> playSample(String ref) async {
    _ensureAlive();
    if (unplayableRefs.contains(ref)) {
      throw AudioError.samplePlaybackFailed(ref, 'ref marked unplayable');
    }
    _interruptCurrent();
    playedRefs.add(ref);
    if (playLatency <= Duration.zero) return;

    final completer = Completer<void>();
    _inFlight = completer;
    _playingRef = ref;
    _timer = Timer(playLatency, () {
      _timer = null;
      _inFlight = null;
      _playingRef = null;
      completer.complete();
    });
    return completer.future;
  }

  @override
  Future<void> stop() async {
    _ensureAlive();
    stopCount++;
    _interruptCurrent();
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _interruptCurrent();
  }

  /// Ends any in-flight playback the way `just_audio` does — the pending
  /// [playSample] future completes (it does not throw) and the ref is recorded
  /// in [interruptedRefs].
  void _interruptCurrent() {
    final completer = _inFlight;
    if (completer == null) return;
    interruptedRefs.add(_playingRef!);
    _timer?.cancel();
    _timer = null;
    _inFlight = null;
    _playingRef = null;
    completer.complete();
  }

  void _ensureAlive() {
    if (disposed) {
      throw StateError('FakeAudioService used after dispose()');
    }
  }
}
