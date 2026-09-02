/// The `ref` → bundled-asset mapping for pre-rendered audio samples.
///
/// This is the contract Story 1.3b satisfies: for every `audioSampleRef` token
/// in the v1 curriculum catalog there must be a mono `.wav` file at the key
/// returned here. It lives in `domain/` because it is a cross-story contract,
/// not a `just_audio` detail. Changing the format or directory is Ask First.
library;

/// The frozen catalog token format. A token outside this shape would yield a
/// broken or path-traversing asset key, so it is rejected outright.
final RegExp _refFormat = RegExp(r'^[a-z0-9_]+$');

/// Maps a catalog sample token (e.g. `sax_c4`) to its bundled asset key
/// (`assets/audio/sax_c4.wav`). Pure — no I/O, no existence check.
///
/// Throws [ArgumentError] when [ref] does not match `^[a-z0-9_]+$` — a real
/// guard, not a debug-only `assert`, so a malformed token can never reach the
/// asset bundle even in a release build.
String audioAssetKeyFor(String ref) {
  if (!_refFormat.hasMatch(ref)) {
    throw ArgumentError.value(ref, 'ref', 'must match ${_refFormat.pattern}');
  }
  return 'assets/audio/$ref.wav';
}
