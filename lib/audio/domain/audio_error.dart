/// Domain errors for the `audio` module.
///
/// A `sealed class` that `implements Exception` — a raw `PlayerException` /
/// `PlatformException` from `just_audio` must never cross the module boundary.
/// Every failure of [AudioService.playSample] surfaces as an [AudioError].
/// The hierarchy is sealed so the recording errors of Story 3.2 can be added
/// without breaking exhaustiveness.
library;

/// Base type for every recoverable audio failure.
sealed class AudioError implements Exception {
  const AudioError();

  /// A pre-rendered sample could not be played: the asset is missing (until
  /// Story 1.3b), corrupted, or the platform player rejected it. [ref] is the
  /// catalog token that was requested; [message] carries the wrapped detail.
  const factory AudioError.samplePlaybackFailed(String ref, String message) =
      SamplePlaybackFailed;
}

/// Playback of the sample identified by [ref] failed.
final class SamplePlaybackFailed extends AudioError {
  const SamplePlaybackFailed(this.ref, this.message);

  /// The catalog sample token that was requested (e.g. `sax_c4`).
  final String ref;

  /// Human-readable detail, typically the wrapped package exception.
  final String message;

  @override
  String toString() => 'AudioError.samplePlaybackFailed: $ref — $message';

  @override
  bool operator ==(Object other) =>
      other is SamplePlaybackFailed &&
      other.ref == ref &&
      other.message == message;

  @override
  int get hashCode => Object.hash('SamplePlaybackFailed', ref, message);
}
