/// The audio port: playback of a single pre-rendered sample by catalog
/// reference. Nothing about recording or pitch evaluation — that is Story 3.2.
library;

export 'audio_error.dart';

/// Plays pre-rendered audio samples identified by their catalog token.
///
/// The real implementation lives in `data/` and is library-private; consumers
/// get it through `audioServiceProvider` (re-exported by the module barrel).
/// Tests get a `FakeAudioService` via a provider override.
abstract interface class AudioService {
  /// Plays the single pre-rendered sample identified by [ref] (e.g. `sax_c4`).
  ///
  /// Interrupts any sample still playing. Completes when playback finishes.
  /// No call limit — replay is free. Every failure surfaces as an
  /// [AudioError] (never a raw `PlayerException` / `PlatformException`).
  /// Throws [StateError] if called after [dispose].
  Future<void> playSample(String ref);

  /// Silences the current sample. No-op when idle. Throws [StateError] if
  /// called after [dispose].
  Future<void> stop();

  /// Releases platform resources. Called by the provider in `onDispose`; the
  /// instance is not reusable afterwards.
  Future<void> dispose();
}
