/// Test-only barrel for the `audio` module.
///
/// Re-exports [FakeAudioService] for suites that override `audioServiceProvider`.
/// Never imported by production code.
library;

export 'testing/fake_audio_service.dart';
