/// Test-only barrel for the `audio` module.
///
/// Re-exports [FakeAudioService] for suites that override `audioServiceProvider`.
/// Never imported by production code — enforced by `check_module_boundaries`
/// Rule 5 (no `lib/` file may reference a module's `testing.dart` / `testing/`).
library;

export 'testing/fake_audio_service.dart';
