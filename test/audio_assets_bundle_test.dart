import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/curriculo/curriculo.dart';
// `phrase_player.dart` is deliberately imported straight from `presentation/`:
// `noteGap` / `flourishGap` are instance fields with defaults, not statics, and
// the module barrel documents this pattern for tests that need them.
import 'package:catear/exercicios/presentation/phrase_player.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Story 1.3b — closes F7 of the Story 1.3 TEA review.
/// Story 1.4b — grows the manifest to 22 tokens and starts reading the PCM.
///
/// `test/audio_service_test.dart` already proves every catalog `audioSampleRef`
/// maps to a well-formed asset *key*. This suite proves the *file* behind each
/// key exists, is loadable through `rootBundle`, and has the exact WAV format
/// the spec's `ffprobe` acceptance criterion demands (PCM / mono / 44.1 kHz /
/// 16-bit / ≤ 2.5 s) — so that criterion is now checked automatically in the
/// `gates` CI job, not just by hand. It also proves `assets/audio/` holds
/// exactly those 22 `.wav` files — no orphans, no leftover placeholder.
///
/// Up to Story 1.4b the header was all it looked at, and the C1 exploratory
/// session (2026-09-04) showed what that misses: 180–320 ms of dead air before
/// every attack and a loudness 3 dB off the declared target passed every check.
/// So the suite now also reads the PCM payload it was already loading —
/// **onset**, **peak** and **RMS** — plus a relational guard tying the worst
/// onset to `PhrasePlayer`'s shortest gap, and the chord-exercise shape
/// (`[triad, root, third, fifth]`) that no gate covered before.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The frozen v1 manifest — union of `audioSampleRefs` in catalog_v1.json:
  // 14 single notes (Story 1.3b) + 8 pre-rendered triads (Story 1.4b).
  const manifest = <String>{
    'sax_c4',
    'sax_db4',
    'sax_d4',
    'sax_eb4',
    'sax_e4',
    'sax_f4',
    'sax_gb4',
    'sax_g4',
    'sax_ab4',
    'sax_a4',
    'sax_bb4',
    'sax_b4',
    'sax_c5',
    'sax_d5',
    'sax_maj_c4',
    'sax_min_c4',
    'sax_dim_c4',
    'sax_aug_c4',
    'sax_maj_d4',
    'sax_min_d4',
    'sax_dim_d4',
    'sax_aug_d4',
  };

  // Story 1.4b: each pre-rendered triad and the three voices mixed into it.
  // Frozen alongside the manifest — `docs/audio/samples-v1.md` §segunda
  // derivação is the same table.
  const triadVoices = <String, List<String>>{
    'sax_maj_c4': ['sax_c4', 'sax_e4', 'sax_g4'],
    'sax_min_c4': ['sax_c4', 'sax_eb4', 'sax_g4'],
    'sax_dim_c4': ['sax_c4', 'sax_eb4', 'sax_gb4'],
    'sax_aug_c4': ['sax_c4', 'sax_e4', 'sax_ab4'],
    'sax_maj_d4': ['sax_d4', 'sax_gb4', 'sax_a4'],
    'sax_min_d4': ['sax_d4', 'sax_f4', 'sax_a4'],
    'sax_dim_d4': ['sax_d4', 'sax_f4', 'sax_ab4'],
    'sax_aug_d4': ['sax_d4', 'sax_gb4', 'sax_bb4'],
  };

  // Nominal fundamental of each note token, in Hz (A4 = 440, equal
  // temperament). Frozen: the token names a pitch, and this is the only place
  // that claim is written down as a number the suite can check.
  const noteHz = <String, double>{
    'sax_c4': 261.63,
    'sax_db4': 277.18,
    'sax_d4': 293.66,
    'sax_eb4': 311.13,
    'sax_e4': 329.63,
    'sax_f4': 349.23,
    'sax_gb4': 369.99,
    'sax_g4': 392.00,
    'sax_ab4': 415.30,
    'sax_a4': 440.00,
    'sax_bb4': 466.16,
    'sax_b4': 493.88,
    'sax_c5': 523.25,
    'sax_d5': 587.33,
  };

  // Mono 16-bit PCM at 44.1 kHz = 88200 bytes per second of audio.
  const sampleRate = 44100;
  const maxDataBytes = 220500; // 88200 * 2.5 s — the frozen duration cap
  const minDataBytes = 88200; // 1.0 s — truncation guard

  // Content thresholds (Story 1.4b, frozen in the spec — fixed numbers, not
  // "with some slack").
  const onsetThreshold = 0.01; // -40 dBFS = 1% of full scale
  const onsetWindowMs = 500; // where the attack is looked for
  const maxOnsetMs = 20.0; // dead air budget before the attack
  const maxPeakDbfs = -1.0; // clipping headroom for the summed voices
  const rmsSpreadDb = 6.0; // sanity band around the median, not level matching
  // Absolute anchor for the whole set. The +/-6 dB band above is relative to
  // the median of the same 22 files, so a *uniform* level regression — exactly
  // C1's finding A-3, a ~3 dB miss across every sample — drags the median with
  // it and leaves every per-sample deviation near zero. This pins the median
  // itself, so the set cannot drift as a block.
  const medianRmsDbfs = -15.85; // measured 2026-09-04, docs/audio/samples-v1.md
  const medianRmsToleranceDb = 1.5; // tighter than A-3's ~3 dB miss

  // Spectral thresholds. Both windows are 100 ms: a 500 ms window loses
  // coherence to the source's own pitch drift and reads a note's *own*
  // fundamental tens of dB down, which would be a false failure.
  const spectralWindowMs = 100;
  const earlyOffsetMs = 30; // after the onset — the attack has spoken by here
  const lateWindowStartMs = 1300; // deep in the sustain, well before the fade
  // Worst measured spread between the three voices of a triad is 3.3 dB.
  const voiceSpreadDb = 8.0;
  // Worst measured margin over a non-harmonic neighbour is 6.4 dB.
  const pitchDominanceDb = 3.0;

  Future<Curriculum> loadCatalog() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(curriculoRepositoryProvider).load();
  }

  Future<Set<String>> catalogSampleRefs() async {
    final curriculum = await loadCatalog();
    return {
      for (final stage in curriculum.stages)
        for (final exercise in stage.exercises) ...exercise.audioSampleRefs,
    };
  }

  /// Loads one token and measures everything the content assertions need.
  Future<_Sample> measure(String ref) async {
    final key = audioAssetKeyFor(ref);
    final ByteData data;
    try {
      data = await rootBundle.load(key);
    } catch (e) {
      fail('catalog ref "$ref" -> "$key" did not resolve to an asset: $e');
    }
    expect(data.lengthInBytes, greaterThan(44), reason: '$key: not a WAV');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final wav = _parseWav(bytes, key);

    // Signed 16-bit little-endian frames, normalised to -1.0 .. 1.0.
    final view = ByteData.sublistView(
      bytes,
      wav.dataOffset,
      wav.dataOffset + wav.dataBytes,
    );
    final frames = wav.dataBytes ~/ 2;
    final pcm = Int16List(frames);
    var peak = 0.0;
    var sumOfSquares = 0.0;
    var onsetFrame = -1;
    final onsetLimit = math.min(frames, onsetWindowMs * sampleRate ~/ 1000);
    for (var i = 0; i < frames; i++) {
      final raw = view.getInt16(i * 2, Endian.little);
      pcm[i] = raw;
      final x = raw / 32768.0;
      final a = x.abs();
      if (a > peak) peak = a;
      sumOfSquares += x * x;
      if (onsetFrame < 0 && i < onsetLimit && a >= onsetThreshold) {
        onsetFrame = i;
      }
    }
    return _Sample(
      ref: ref,
      key: key,
      wav: wav,
      pcm: pcm,
      onsetFrame: onsetFrame < 0 ? null : onsetFrame,
      onsetMs: onsetFrame < 0 ? null : onsetFrame * 1000 / sampleRate,
      peakDbfs: _dbfs(peak),
      rmsDbfs: _dbfs(math.sqrt(sumOfSquares / frames)),
    );
  }

  // Decoding and scanning all 22 payloads is the expensive part of this suite
  // and the result cannot change within a run, so every test awaits the same
  // future instead of redoing the work.
  late final Future<List<_Sample>> allSamples = () async {
    final refs = await catalogSampleRefs();
    expect(refs, isNotEmpty, reason: 'the catalog references audio samples');
    return [for (final ref in refs) await measure(ref)];
  }();

  group('audio sample bundle', () {
    test(
      'the catalog references exactly the frozen 22-token manifest',
      () async {
        final refs = await catalogSampleRefs();
        expect(refs, equals(manifest));
      },
    );

    test(
      'every audioSampleRef loads from rootBundle as a conformant WAV',
      () async {
        for (final s in await allSamples) {
          final key = s.key;
          expect(
            s.wav.audioFormat,
            1,
            reason: '$key: must be PCM (audioFormat 1)',
          );
          expect(s.wav.numChannels, 1, reason: '$key: must be mono');
          expect(
            s.wav.sampleRate,
            sampleRate,
            reason: '$key: must be 44.1 kHz',
          );
          expect(s.wav.bitsPerSample, 16, reason: '$key: must be 16-bit');
          expect(
            s.wav.dataBytes,
            lessThanOrEqualTo(maxDataBytes),
            reason:
                '$key: PCM payload ${s.wav.dataBytes}B exceeds the 2.5 s cap',
          );
          expect(
            s.wav.dataBytes,
            greaterThan(minDataBytes),
            reason:
                '$key: PCM payload ${s.wav.dataBytes}B looks truncated (< 1 s)',
          );
        }
      },
    );

    test('the attack starts within 20 ms of the file start', () async {
      for (final s in await allSamples) {
        expect(
          s.onsetMs,
          isNotNull,
          reason:
              '${s.key}: no sample above -40 dBFS in the first '
              '$onsetWindowMs ms — silent or truncated',
        );
        expect(
          s.onsetMs,
          lessThanOrEqualTo(maxOnsetMs),
          reason:
              '${s.key}: attack starts at ${s.onsetMs!.toStringAsFixed(1)} ms; '
              'dead air before the attack must be <= $maxOnsetMs ms '
              '(C1 finding A-2)',
        );
      }
    });

    test('no sample peaks above -1.0 dBFS', () async {
      for (final s in await allSamples) {
        expect(
          s.peakDbfs,
          lessThanOrEqualTo(maxPeakDbfs),
          reason:
              '${s.key}: peak ${s.peakDbfs.toStringAsFixed(2)} dBFS leaves no '
              'headroom (summing three voices needs it)',
        );
      }
    });

    test('every sample RMS is within +/-6 dB of the median', () async {
      // A wide sanity band against truncation and silence, *not* level
      // matching: perceived level is governed by the measured LUFS, and a
      // dense triad has a different crest factor than a single note.
      final samples = await allSamples;
      final sorted = [for (final s in samples) s.rmsDbfs]..sort();
      final mid = sorted.length ~/ 2;
      final median = sorted.length.isOdd
          ? sorted[mid]
          : (sorted[mid - 1] + sorted[mid]) / 2;
      for (final s in samples) {
        expect(
          (s.rmsDbfs - median).abs(),
          lessThanOrEqualTo(rmsSpreadDb),
          reason:
              '${s.key}: RMS ${s.rmsDbfs.toStringAsFixed(2)} dBFS is more than '
              '$rmsSpreadDb dB off the median ${median.toStringAsFixed(2)} dBFS',
        );
      }

      // The anchor. Without it the band above is self-referential: a uniform
      // miss (A-3) moves the median and every deviation stays near zero.
      expect(
        (median - medianRmsDbfs).abs(),
        lessThanOrEqualTo(medianRmsToleranceDb),
        reason:
            'the median RMS of the 22 is ${median.toStringAsFixed(2)} dBFS, '
            'more than $medianRmsToleranceDb dB off the '
            '$medianRmsDbfs dBFS the set was rendered to — the whole set has '
            'drifted, which is what C1 finding A-3 was',
      );
    });

    test(
      'the worst onset stays under half of PhrasePlayer\'s shortest gap',
      () async {
        // The relational half of the A-2 guard: the flourish only works
        // because every gap outlasts the dead air ahead of the attack. Nothing
        // enforced that coupling before — the fake models "playSample was
        // called", not "a sound came out".
        final player = PhrasePlayer(FakeAudioService());
        final shortestGapMs =
            math.min(
              player.noteGap.inMicroseconds,
              player.flourishGap.inMicroseconds,
            ) /
            1000.0;
        final samples = await allSamples;
        // A missing onset (a silent sample) is the worst case, not the best:
        // `?? double.infinity` on both sides makes it win the reduce instead of
        // being skipped over, and the `isNotNull` below names it.
        final worst = samples.reduce(
          (a, b) =>
              (a.onsetMs ?? double.infinity) >= (b.onsetMs ?? double.infinity)
              ? a
              : b,
        );
        expect(
          worst.onsetMs,
          isNotNull,
          reason: '${worst.key}: no detectable attack at all',
        );
        expect(
          worst.onsetMs,
          lessThanOrEqualTo(shortestGapMs / 2),
          reason:
              '${worst.key}: onset ${worst.onsetMs!.toStringAsFixed(1)} ms is '
              'more than half the shortest PhrasePlayer gap '
              '(${shortestGapMs.toStringAsFixed(0)} ms) — notes would be cut '
              'before their own attack',
        );
      },
    );

    test('every sample carries the pitches its token names', () async {
      // The property this whole story exists to guarantee, and the only one
      // that notices `sax_c4.wav` copied over `sax_maj_c4.wav` or two triads
      // swapped: every other assertion here — manifest, header, onset, peak,
      // RMS, pairing, orphans — is pitch-agnostic, and the e2e group only
      // asserts that playback does not throw.
      //
      // Two windows, because a single one is not enough: the early one catches
      // a voice that never speaks, the late one catches a voice that stops.
      // Both are 100 ms — a longer window loses coherence to the source's own
      // pitch drift and reads a note's *own* fundamental far down.
      for (final s in await allSamples) {
        final voices = triadVoices[s.ref] ?? [s.ref];
        final expectedHz = <double>[
          for (final v in voices)
            noteHz[v] ?? (fail('${s.key}: no frozen frequency for voice "$v"')),
        ];
        final onset = s.onsetFrame;
        expect(onset, isNotNull, reason: '${s.key}: no detectable attack');

        final windows = <String, int>{
          'early (onset + $earlyOffsetMs ms)':
              onset! + earlyOffsetMs * sampleRate ~/ 1000,
          'late (${lateWindowStartMs}ms)':
              lateWindowStartMs * sampleRate ~/ 1000,
        };

        for (final entry in windows.entries) {
          final mags = <String, double>{
            for (final token in noteHz.keys)
              token: _dbfs(
                _goertzel(
                  s.pcm,
                  entry.value,
                  spectralWindowMs * sampleRate ~/ 1000,
                  noteHz[token]!,
                  sampleRate,
                ),
              ),
          };
          final voiceMags = [for (final v in voices) mags[v]!];
          final strongest = voiceMags.reduce(math.max);
          final weakest = voiceMags.reduce(math.min);

          // (a) every named voice is present, and they sound *together* —
          //     a triad whose third dropped out reads as a wide spread.
          expect(
            strongest - weakest,
            lessThanOrEqualTo(voiceSpreadDb),
            reason:
                '${s.key} ${entry.key}: the voices $voices measure '
                '${voiceMags.map((v) => v.toStringAsFixed(1)).toList()} dB — '
                'a spread over $voiceSpreadDb dB means one of them is not '
                'sounding with the others',
          );

          // (b) nothing the token does *not* name is louder. Harmonically
          //     related candidates are skipped: a sax note's own octave is
          //     genuinely strong at the octave token's fundamental, and that
          //     is the instrument, not a wrong file.
          for (final token in noteHz.keys) {
            if (voices.contains(token)) continue;
            if (expectedHz.any(
              (f) => _harmonicallyRelated(noteHz[token]!, f),
            )) {
              continue;
            }
            expect(
              weakest,
              greaterThanOrEqualTo(mags[token]! + pitchDominanceDb),
              reason:
                  '${s.key} ${entry.key}: ${noteHz[token]} Hz ($token) reads '
                  '${mags[token]!.toStringAsFixed(1)} dB, not '
                  '$pitchDominanceDb dB below the weakest named voice '
                  '(${weakest.toStringAsFixed(1)} dB) — this file does not '
                  'sound like what its token names',
            );
          }
        }
      }
    });

    test('the flourish only reaches for refs the manifest guarantees', () async {
      // `PhrasePlayer.flourishRefs` is hardcoded and `playFlourish` swallows
      // failures, so a catalog change that drops one of these tokens would
      // delete the file (the orphan test demands it) and mute the flourish
      // silently — the exact symptom the C1 session was opened to diagnose.
      expect(
        manifest,
        containsAll(PhrasePlayer.flourishRefs),
        reason:
            'PhrasePlayer.flourishRefs ${PhrasePlayer.flourishRefs} must stay '
            'inside the frozen manifest; missing: '
            '${PhrasePlayer.flourishRefs.toSet().difference(manifest)}',
      );
    });

    test(
      'assets/audio/ contains exactly the catalog tokens, no orphans',
      () async {
        final refs = await catalogSampleRefs();
        final expectedFiles = {for (final ref in refs) '$ref.wav'};

        final dir = Directory('assets/audio');
        expect(dir.existsSync(), isTrue, reason: 'assets/audio/ must exist');

        final actualFiles = dir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => n.endsWith('.wav'))
            .toSet();

        expect(
          actualFiles,
          equals(expectedFiles),
          reason:
              'assets/audio/ must hold one .wav per catalog token and nothing '
              'else. missing: ${expectedFiles.difference(actualFiles)} '
              'orphans: ${actualFiles.difference(expectedFiles)}',
        );
      },
    );

    test('every chord exercise is a triad block plus its three voices', () async {
      final curriculum = await loadCatalog();
      final chords = curriculum.stages
          .expand((s) => s.exercises)
          .whereType<ChordExercise>()
          .toList();
      expect(
        chords.length,
        triadVoices.length,
        reason: 'one chord exercise per pre-rendered triad',
      );

      final seen = <String>{};
      for (final e in chords) {
        final refs = e.audioSampleRefs;
        expect(
          refs.length,
          4,
          reason:
              '${e.chord.id}: a chord exercise is [triad, root, third, fifth]; '
              'got $refs',
        );
        final block = refs.first;
        expect(
          triadVoices.keys,
          contains(block),
          reason: '${e.chord.id}: refs[0] "$block" is not a triad token',
        );
        expect(
          refs.sublist(1),
          equals(triadVoices[block]),
          reason:
              '$block: refs[1..3] must be exactly the voices mixed into it '
              '(${triadVoices[block]}); got ${refs.sublist(1)}',
        );
        final fragment = _qualityToken[e.chord.id];
        expect(
          fragment,
          isNotNull,
          reason:
              'chordQuality "${e.chord.id}" has no token fragment — extend '
              '_qualityToken alongside the manifest',
        );
        expect(
          block,
          contains('_${fragment}_'),
          reason:
              '$block: token quality must match chordQuality "${e.chord.id}"',
        );
        expect(seen.add(block), isTrue, reason: '$block used twice');
      }
      expect(seen, equals(triadVoices.keys.toSet()));
    });

    test('s-acordes and s-escalas each carry 8 exercises', () async {
      final curriculum = await loadCatalog();
      Iterable<Exercise> stage(String id) => curriculum.stages
          .firstWhere(
            (s) => s.stageId == id,
            orElse: () => fail('the catalog has no stage "$id"'),
          )
          .exercises;
      expect(
        stage('s-acordes').length,
        8,
        reason: '4 qualities x 2 roots — the 1.5 screen needs 4 options',
      );
      expect(
        stage('s-escalas').length,
        8,
        reason: '4 modes x asc/desc — the 1.5 screen needs 4 options',
      );
    });
  });
}

/// `chordQuality` id -> the fragment that names it in the sample token.
const _qualityToken = <String, String>{
  'major': 'maj',
  'minor': 'min',
  'diminished': 'dim',
  'augmented': 'aug',
};

/// Magnitude of [hz] over [length] frames of [pcm] starting at [start], via the
/// Goertzel algorithm (one bin, no FFT dependency). A Hann window keeps a
/// neighbouring semitone from leaking into the bin.
double _goertzel(Int16List pcm, int start, int length, double hz, int rate) {
  final n = math.min(length, pcm.length - start);
  if (n <= 0) return 0;
  final k = (0.5 + n * hz / rate).floor();
  final w = 2 * math.pi * k / n;
  final coeff = 2 * math.cos(w);
  var s1 = 0.0, s2 = 0.0;
  for (var i = 0; i < n; i++) {
    // Hann window, applied inline so no second buffer is allocated.
    final hann = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
    final s0 = (pcm[start + i] / 32768.0) * hann + coeff * s1 - s2;
    s2 = s1;
    s1 = s0;
  }
  final power = s1 * s1 + s2 * s2 - coeff * s1 * s2;
  return math.sqrt(power < 0 ? 0 : power) / n;
}

/// Whether [a] sits within 2% of a low-order harmonic (or subharmonic) of [b].
/// A real note is loud at its own octave, so the octave token's fundamental is
/// not evidence of a wrong file.
bool _harmonicallyRelated(double a, double b) {
  for (var k = 1; k <= 6; k++) {
    if ((a - k * b).abs() / (k * b) < 0.02) return true;
    if ((b - k * a).abs() / (k * a) < 0.02) return true;
  }
  return false;
}

double _dbfs(double amplitude) =>
    amplitude <= 0 ? -1000.0 : 20 * (math.log(amplitude) / math.ln10);

class _Sample {
  const _Sample({
    required this.ref,
    required this.key,
    required this.wav,
    required this.pcm,
    required this.onsetFrame,
    required this.onsetMs,
    required this.peakDbfs,
    required this.rmsDbfs,
  });

  final String ref;
  final String key;
  final _WavHeader wav;

  /// The decoded 16-bit frames, kept so the spectral assertions do not have to
  /// re-read the asset.
  final Int16List pcm;

  /// Index of the first frame at or above the onset threshold, or `null`.
  final int? onsetFrame;

  /// Milliseconds until the first frame at or above -40 dBFS, or `null` when
  /// the search window held nothing that loud.
  final double? onsetMs;
  final double peakDbfs;
  final double rmsDbfs;
}

typedef _WavHeader = ({
  int audioFormat,
  int numChannels,
  int sampleRate,
  int bitsPerSample,
  int dataOffset,
  int dataBytes,
});

/// Minimal RIFF/WAVE header parser — walks the chunk list so an interleaved
/// `LIST`/`fact` chunk (ffmpeg sometimes emits one) does not hide `data`.
_WavHeader _parseWav(Uint8List b, String label) {
  String tag(int o) => String.fromCharCodes(b.sublist(o, o + 4));
  final bd = ByteData.sublistView(b);

  if (b.lengthInBytes < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    fail('$label: not a RIFF/WAVE file');
  }

  int? audioFormat, numChannels, sampleRate, bitsPerSample;
  int? dataOffset, dataBytes;
  var off = 12;
  while (off + 8 <= b.lengthInBytes) {
    final id = tag(off);
    final size = bd.getUint32(off + 4, Endian.little);
    final body = off + 8;
    if (id == 'fmt ' && body + 16 <= b.lengthInBytes) {
      audioFormat = bd.getUint16(body, Endian.little);
      numChannels = bd.getUint16(body + 2, Endian.little);
      sampleRate = bd.getUint32(body + 4, Endian.little);
      bitsPerSample = bd.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      dataOffset = body;
      final available = b.lengthInBytes - body;
      // The clamp keeps the reads in bounds; the assertion is what makes a
      // truncated file fail loudly instead of being silently shortened.
      expect(
        size,
        lessThanOrEqualTo(available),
        reason:
            '$label: the data chunk declares ${size}B but only ${available}B '
            'follow it — the file is truncated',
      );
      dataBytes = math.min(size, available);
      break;
    }
    off = body + size + (size.isOdd ? 1 : 0);
  }

  if (audioFormat == null || dataBytes == null) {
    fail('$label: missing fmt or data chunk');
  }
  return (
    audioFormat: audioFormat,
    numChannels: numChannels!,
    sampleRate: sampleRate!,
    bitsPerSample: bitsPerSample!,
    dataOffset: dataOffset!,
    dataBytes: dataBytes,
  );
}
