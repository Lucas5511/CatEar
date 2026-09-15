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

/// The isolated **note** tokens of the v1 sample set, mapped to semitones above
/// C4 (`sax_c4` = 0).
///
/// Why this table lives here and not in the catalog (human decision,
/// 2026-09-09): what a token *sounds like* is a property of the sample set,
/// which this module already owns — [audioAssetKeyFor] and the token vocabulary
/// are both here. Making it a catalog field would move the curriculum
/// `schemaVersion`, which is Ask First since Story 1.2, to record something the
/// curriculum does not decide.
///
/// The inventory is deliberately irregular: C4-C5 chromatic plus D5, with
/// **no Db5** (13 semitones). Story 1.8 transposes inside it, so a caller must
/// ask whether a note exists rather than assume it — see [transposedNoteToken].
///
/// The 8 pre-rendered triad blocks (`sax_maj_c4`, …) are absent on purpose:
/// their root is baked into the file, so they cannot be transposed and are not
/// notes. Looking one up returns `null`, which is the correct answer.
const Map<String, int> noteSemitonesByToken = {
  'sax_c4': 0,
  'sax_db4': 1,
  'sax_d4': 2,
  'sax_eb4': 3,
  'sax_e4': 4,
  'sax_f4': 5,
  'sax_gb4': 6,
  'sax_g4': 7,
  'sax_ab4': 8,
  'sax_a4': 9,
  'sax_bb4': 10,
  'sax_b4': 11,
  'sax_c5': 12,
  // 13 (Db5) is missing from the sample set — the gap the transposition code
  // has to survive rather than paper over.
  'sax_d5': 14,
};

/// Reverse index of [noteSemitonesByToken]. Built once; the map is a `const`
/// literal with no duplicate values, so this is a bijection.
final Map<int, String> _noteTokenBySemitone = {
  for (final entry in noteSemitonesByToken.entries) entry.value: entry.key,
};

/// The isolated-note tokens ordered from the lowest pitch up.
///
/// A stable, pitch-ordered list rather than map order, so anything that picks
/// "the first available root" picks the same one on every run.
final List<String> noteTokensByPitch = List.unmodifiable(
  noteSemitonesByToken.keys.toList()..sort(
    (a, b) => noteSemitonesByToken[a]!.compareTo(noteSemitonesByToken[b]!),
  ),
);

/// The note token sitting exactly [semitone] semitones above C4, or `null`
/// when the sample set has no such note.
String? noteTokenAtSemitone(int semitone) => _noteTokenBySemitone[semitone];

/// The note token [semitones] above [ref], or `null` when either [ref] is not
/// an isolated note (a triad block, or an unknown token) or the sample set has
/// no note at that distance.
///
/// `null` is the whole point: the inventory has holes, so "transpose this by
/// N" is a question, not an operation. A caller that ignores the `null` would
/// build an `audioSampleRef` with no file behind it.
String? transposedNoteToken(String ref, int semitones) {
  final base = noteSemitonesByToken[ref];
  if (base == null) return null;
  return _noteTokenBySemitone[base + semitones];
}
