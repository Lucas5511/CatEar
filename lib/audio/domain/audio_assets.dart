/// The `ref` → bundled-asset mapping for pre-rendered audio samples.
///
/// This is the contract Story 1.3b satisfies: for every `audioSampleRef` token
/// in the v1 curriculum catalog there must be a mono `.wav` file at the key
/// returned here. It lives in `domain/` because it is a cross-story contract,
/// not a `just_audio` detail. Changing the format or directory is Ask First.
library;

/// Maps a catalog sample token (e.g. `sax_c4`) to its bundled asset key
/// (`assets/audio/sax_c4.wav`). Pure — no I/O, no existence check.
///
/// [ref] must match the frozen catalog token format `^[a-z0-9_]+$`; a
/// malformed token would otherwise yield a broken or path-traversing key.
String audioAssetKeyFor(String ref) {
  assert(RegExp(r'^[a-z0-9_]+$').hasMatch(ref), 'ref inválido: $ref');
  return 'assets/audio/$ref.wav';
}
