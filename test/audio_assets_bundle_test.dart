import 'dart:io';
import 'dart:typed_data';

import 'package:catear/audio/audio.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Story 1.3b — closes F7 of the Story 1.3 TEA review.
///
/// `test/audio_service_test.dart` already proves every catalog `audioSampleRef`
/// maps to a well-formed asset *key*. This suite proves the *file* behind each
/// key exists, is loadable through `rootBundle`, and has the exact WAV format
/// the spec's `ffprobe` acceptance criterion demands (PCM / mono / 44.1 kHz /
/// 16-bit / ≤ 2.5 s) — so that criterion is now checked automatically in the
/// `gates` CI job, not just by hand. It also proves `assets/audio/` holds
/// exactly those 14 `.wav` files — no orphans, no leftover placeholder.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The frozen v1 manifest — union of `audioSampleRefs` in catalog_v1.json.
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
  };

  // Mono 16-bit PCM at 44.1 kHz = 88200 bytes per second of audio.
  const maxDataBytes = 220500; // 88200 * 2.5 s — the frozen duration cap
  const minDataBytes = 88200; // 1.0 s — truncation guard

  Future<Set<String>> catalogSampleRefs() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final curriculum = await container.read(curriculoRepositoryProvider).load();
    return {
      for (final stage in curriculum.stages)
        for (final exercise in stage.exercises) ...exercise.audioSampleRefs,
    };
  }

  group('audio sample bundle', () {
    test(
      'the catalog references exactly the frozen 14-token manifest',
      () async {
        final refs = await catalogSampleRefs();
        expect(refs, equals(manifest));
      },
    );

    test(
      'every audioSampleRef loads from rootBundle as a conformant WAV',
      () async {
        final refs = await catalogSampleRefs();
        expect(
          refs,
          isNotEmpty,
          reason: 'the catalog references audio samples',
        );

        for (final ref in refs) {
          final key = audioAssetKeyFor(ref);
          final ByteData data;
          try {
            data = await rootBundle.load(key);
          } catch (e) {
            fail(
              'catalog ref "$ref" -> "$key" did not resolve to an asset: $e',
            );
          }
          expect(
            data.lengthInBytes,
            greaterThan(44),
            reason: '$key: not a WAV',
          );

          final wav = _parseWav(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            key,
          );
          expect(
            wav.audioFormat,
            1,
            reason: '$key: must be PCM (audioFormat 1)',
          );
          expect(wav.numChannels, 1, reason: '$key: must be mono');
          expect(wav.sampleRate, 44100, reason: '$key: must be 44.1 kHz');
          expect(wav.bitsPerSample, 16, reason: '$key: must be 16-bit');
          expect(
            wav.dataBytes,
            lessThanOrEqualTo(maxDataBytes),
            reason: '$key: PCM payload ${wav.dataBytes}B exceeds the 2.5 s cap',
          );
          expect(
            wav.dataBytes,
            greaterThan(minDataBytes),
            reason:
                '$key: PCM payload ${wav.dataBytes}B looks truncated (< 1 s)',
          );
        }
      },
    );

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
  });
}

typedef _WavHeader = ({
  int audioFormat,
  int numChannels,
  int sampleRate,
  int bitsPerSample,
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

  int? audioFormat, numChannels, sampleRate, bitsPerSample, dataBytes;
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
      dataBytes = size;
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
    dataBytes: dataBytes,
  );
}
