/// Public barrel for the `audio` module.
///
/// Re-exports only from `domain/` (the [AudioService] port, the [AudioError]
/// hierarchy, and `audioAssetKeyFor`) plus the single provider from `data/`.
/// Nothing else touches `data/`; no other module imports `package:just_audio/…`.
/// `presentation/` is empty in this story. The `FakeAudioService` lives in the
/// separate `testing.dart` barrel.
library;

export 'data/audio_service_impl.dart' show audioServiceProvider;
export 'domain/audio_assets.dart';
// Exposes AudioService plus the AudioError hierarchy it re-exports.
export 'domain/audio_service.dart';
