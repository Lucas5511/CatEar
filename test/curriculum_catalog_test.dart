import 'dart:convert';
import 'dart:io';

import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/curriculo/data/catalog_asset_bundle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/curriculum_fixtures.dart';

/// (a) Round-trips the real `assets/curriculum/catalog_v1.json` through
///     `CurriculoRepository.load()` and asserts structural coverage.
/// (b) Feeds bad fixtures via an overridden [catalogAssetBundleProvider] — one
///     case per [CurriculumError] subtype and per `load()` rule.
/// (c) Guards the module's public surface.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Curriculum> loadReal() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(curriculoRepositoryProvider).load();
  }

  Future<Object?> loadErrorFrom(String? payload) async {
    final container = ProviderContainer(
      overrides: [
        catalogAssetBundleProvider.overrideWithValue(_FakeBundle(payload)),
      ],
    );
    addTearDown(container.dispose);
    try {
      await container.read(curriculoRepositoryProvider).load();
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<Curriculum> loadFrom(String payload) async {
    final container = ProviderContainer(
      overrides: [
        catalogAssetBundleProvider.overrideWithValue(_FakeBundle(payload)),
      ],
    );
    addTearDown(container.dispose);
    return container.read(curriculoRepositoryProvider).load();
  }

  // ---- (a) the real catalog -------------------------------------------

  group('catalog_v1.json via load()', () {
    test('10 stages, returned sorted by order', () async {
      final c = await loadReal();
      expect(c.schemaVersion, 1);
      expect(c.stages.length, 10);
      expect(
        c.stages.map((s) => s.order).toList(),
        List.generate(10, (i) => i + 1),
        reason: 'stages come back in ascending order',
      );
    });

    test('a shuffled stages array still loads sorted by order', () async {
      final c = await loadFrom(
        catalogFixtureString(
          (j) => j['stages'] = stagesOf(j).reversed.toList(),
        ),
      );
      expect(c.stages.map((s) => s.order).toList(), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ]);
      expect(c.stages.first.stageId, 's-consonancias');
    });

    test('errorTypes is exactly the ErrorType set', () async {
      final c = await loadReal();
      expect(c.errorTypes, ErrorType.values.toSet());
    });

    test('every *Catalog id is referenced by >=1 exercise, and every '
        'content-model id appears', () async {
      final c = await loadReal();
      final intervals = <String>{};
      final scales = <String>{};
      final chords = <String>{};
      final cadences = <String>{};
      for (final e in c.stages.expand((s) => s.exercises)) {
        switch (e) {
          case IntervalExercise():
            intervals.add(e.interval.id);
          case ScaleExercise():
            scales.add(e.scale.id);
          case ChordExercise():
            chords.add(e.chord.id);
          case ResolutionExercise():
            cadences.add(e.cadence.id);
        }
      }

      // content-model §1 / §3 / §4 / §5 — the canonical v1 ids.
      expect(intervals, {
        'P1', 'm2', 'M2', 'm3', 'M3', 'P4', 'TT', 'P5', 'm6', 'M6', 'm7',
        'M7', 'P8', //
      });
      expect(chords, {'major', 'minor', 'diminished', 'augmented'});
      expect(scales, {'major', 'natural_minor', 'dorian', 'mixolydian'});
      expect(cadences, {'authentic', 'plagal'});

      // and no catalog entry is left unreferenced.
      final raw = realCatalogJson;
      Set<String> ids(String key) => {
        for (final e in raw[key] as List) (e as Map)['id'] as String,
      };
      expect(intervals, ids('intervalCatalog'));
      expect(chords, ids('chordCatalog'));
      expect(scales, ids('scaleCatalog'));
      expect(cadences, ids('cadenceCatalog'));
    });

    test('direction: order-1 stage is asc-only; desc appears later', () async {
      final c = await loadReal();
      final first = c.stages.first.exercises.whereType<IntervalExercise>();
      expect(first, isNotEmpty);
      expect(first.every((e) => e.direction == Direction.asc), isTrue);
      expect(
        c.stages
            .expand((s) => s.exercises)
            .whereType<IntervalExercise>()
            .any((e) => e.direction == Direction.desc),
        isTrue,
      );
    });

    test(
      'scaffoldIntensity + timbreScaffold load; a null hole is preserved',
      () async {
        final c = await loadReal();
        expect(c.stages.where((s) => s.scaffoldIntensity != null), isNotEmpty);
        expect(
          c.stages.any((s) => s.scaffoldIntensity == null),
          isTrue,
          reason: 's-resolucao has no scaffoldIntensity',
        );
        expect(
          c.stages
              .map((s) => s.timbreScaffold)
              .whereType<TimbreScaffold>()
              .toSet(),
          {TimbreScaffold.clean, TimbreScaffold.vibrato},
        );
      },
    );

    test('requiresVoice true iff ResolutionExercise', () async {
      final c = await loadReal();
      for (final e in c.stages.expand((s) => s.exercises)) {
        expect(e.requiresVoice, e is ResolutionExercise, reason: '$e');
      }
      expect(
        c.stages.expand((s) => s.exercises).whereType<ResolutionExercise>(),
        isNotEmpty,
      );
    });

    test('audioSampleRefs are non-empty opaque tokens', () async {
      final c = await loadReal();
      final re = RegExp(r'^[a-z0-9_]+$');
      for (final e in c.stages.expand((s) => s.exercises)) {
        expect(e.audioSampleRefs, isNotEmpty);
        expect(e.audioSampleRefs.every(re.hasMatch), isTrue);
      }
    });
  });

  // ---- (b) error mapping --------------------------------------------

  group('load() error mapping', () {
    test('asset missing -> AssetNotFound', () async {
      expect(await loadErrorFrom(null), isA<AssetNotFound>());
    });

    test('unreadable JSON -> MalformedCatalog', () async {
      expect(await loadErrorFrom('{ not json'), isA<MalformedCatalog>());
    });

    for (final entry in {'array': '[]', 'int': '42', 'null': 'null'}.entries) {
      test(
        'scalar/array root (${entry.key}) -> MalformedCatalog(<root>)',
        () async {
          final e = await loadErrorFrom(entry.value);
          expect(e, isA<MalformedCatalog>());
          expect((e! as MalformedCatalog).path, '<root>');
        },
      );
    }

    test('schemaVersion 2 -> MalformedCatalog(schemaVersion)', () async {
      final e = await loadErrorFrom(
        catalogFixtureString((j) => j['schemaVersion'] = 2),
      );
      expect((e! as MalformedCatalog).path, 'schemaVersion');
    });

    test(
      'schemaVersion "1" (string) -> MalformedCatalog(schemaVersion)',
      () async {
        final e = await loadErrorFrom(
          catalogFixtureString((j) => j['schemaVersion'] = '1'),
        );
        expect((e! as MalformedCatalog).path, 'schemaVersion');
      },
    );

    test('schemaVersion absent -> MalformedCatalog(schemaVersion)', () async {
      final e = await loadErrorFrom(
        catalogFixtureString((j) => j.remove('schemaVersion')),
      );
      expect((e! as MalformedCatalog).path, 'schemaVersion');
    });

    test('stages key absent -> MalformedCatalog(stages)', () async {
      final e = await loadErrorFrom(
        catalogFixtureString((j) => j.remove('stages')),
      );
      expect((e! as MalformedCatalog).path, 'stages');
    });

    test('errorTypes key absent -> MalformedCatalog(errorTypes)', () async {
      final e = await loadErrorFrom(
        catalogFixtureString((j) => j.remove('errorTypes')),
      );
      expect((e! as MalformedCatalog).path, 'errorTypes');
    });

    test('errorTypes missing an id -> MalformedCatalog', () async {
      final e = await loadErrorFrom(
        catalogFixtureString((j) => (j['errorTypes'] as List).remove('P1')),
      );
      expect(e, isA<MalformedCatalog>());
    });

    test('errorTypes extra unknown id -> UnknownValue', () async {
      expect(
        await loadErrorFrom(
          catalogFixtureString((j) => (j['errorTypes'] as List).add('ZZ')),
        ),
        isA<UnknownValue>(),
      );
    });

    for (final f in <MapEntry<String, void Function(Map<String, dynamic>)>>[
      MapEntry(
        'unknown exerciseType',
        (j) => exercisesOf(stagesOf(j).first).first['exerciseType'] = 'arp',
      ),
      MapEntry(
        'unknown direction',
        (j) => exercisesOf(stagesOf(j).first).first['direction'] = 'up',
      ),
      MapEntry(
        'unknown timbreScaffold',
        (j) => stagesOf(j).first['timbreScaffold'] = 'warble',
      ),
      MapEntry(
        'orphan interval id',
        (j) => exercisesOf(stagesOf(j).first).first['interval'] = 'P9',
      ),
    ]) {
      test('${f.key} -> UnknownValue', () async {
        expect(
          await loadErrorFrom(catalogFixtureString(f.value)),
          isA<UnknownValue>(),
        );
      });
    }

    for (final f in <MapEntry<String, void Function(Map<String, dynamic>)>>[
      MapEntry('empty stages', (j) => j['stages'] = <dynamic>[]),
      MapEntry(
        'empty exercises',
        (j) => stagesOf(j).first['exercises'] = <dynamic>[],
      ),
      MapEntry(
        'duplicate stageId',
        (j) => stagesOf(j)[1]['stageId'] = stagesOf(j)[0]['stageId'],
      ),
      MapEntry('order not an int', (j) => stagesOf(j).first['order'] = 'x'),
      MapEntry(
        'scaffoldIntensity out of range',
        (j) => stagesOf(j).first['scaffoldIntensity'] = 1.5,
      ),
      MapEntry(
        'audioSampleRefs empty',
        (j) => exercisesOf(stagesOf(j).first).first['audioSampleRefs'] =
            <dynamic>[],
      ),
      MapEntry(
        'audioSampleRefs bad token',
        (j) => exercisesOf(stagesOf(j).first).first['audioSampleRefs'] = [
          'Piano C4',
        ],
      ),
      MapEntry(
        'audioSampleRefs bare string',
        (j) =>
            exercisesOf(stagesOf(j).first).first['audioSampleRefs'] = 'sax_c4',
      ),
      MapEntry(
        'requiresVoice on an interval',
        (j) => exercisesOf(stagesOf(j).first).first['requiresVoice'] = true,
      ),
      MapEntry(
        'resolution without requiresVoice',
        (j) =>
            exercisesOf(stageById(j, 's-resolucao')).first
                .remove('requiresVoice'),
      ),
      MapEntry(
        'direction on a chord',
        (j) =>
            exercisesOf(stageById(j, 's-acordes')).first['direction'] = 'asc',
      ),
      MapEntry(
        'interval missing direction',
        (j) => exercisesOf(stagesOf(j).first).first.remove('direction'),
      ),
      MapEntry(
        'intervalCatalog entry missing nameUi',
        (j) => (j['intervalCatalog'] as List).first.remove('nameUi'),
      ),
      MapEntry(
        'intervalCatalog semitones wrong type',
        (j) => (j['intervalCatalog'] as List).first['semitones'] = 'x',
      ),
      MapEntry(
        'chordCatalog missing inversion',
        (j) => (j['chordCatalog'] as List).first.remove('inversion'),
      ),
      MapEntry(
        'scaleCatalog steps not a list',
        (j) => (j['scaleCatalog'] as List).first['steps'] = 7,
      ),
      MapEntry(
        'cadenceCatalog missing degrees',
        (j) => (j['cadenceCatalog'] as List).first.remove('degrees'),
      ),
    ]) {
      test('${f.key} -> MalformedCatalog', () async {
        expect(
          await loadErrorFrom(catalogFixtureString(f.value)),
          isA<MalformedCatalog>(),
        );
      });
    }
  });

  // ---- (c) module surface ------------------------------------------

  group('module public surface', () {
    test('barrel exports only domain/ + the provider file', () {
      final barrel = File('lib/curriculo/curriculo.dart').readAsStringSync();
      final exports = RegExp(r"export\s+'([^']+)'")
          .allMatches(barrel)
          .map((m) => m.group(1)!)
          .toList();
      expect(exports, isNotEmpty);
      for (final e in exports) {
        final ok =
            e.startsWith('domain/') ||
            e == 'data/curriculo_repository_impl.dart';
        expect(ok, isTrue, reason: 'barrel must not export "$e"');
      }
      // The impl file may only leak the provider.
      final implLine = exports.firstWhere(
        (e) => e.startsWith('data/'),
        orElse: () => '',
      );
      if (implLine.isNotEmpty) {
        final directive = RegExp("export\\s+'${RegExp.escape(implLine)}'[^;]*;")
            .firstMatch(barrel)!
            .group(0)!;
        expect(directive, contains('show curriculoRepositoryProvider'));
        expect(directive.contains('_AssetCurriculoRepository'), isFalse);
        expect(directive.contains('catalogAssetBundle'), isFalse);
      }
    });

    test('the private impl symbols are not reachable through the barrel', () {
      final barrelSymbols = File('lib/curriculo/curriculo.dart')
          .readAsStringSync();
      expect(barrelSymbols.contains('_AssetCurriculoRepository'), isFalse);
      expect(barrelSymbols.contains('catalogAssetBundleProvider'), isFalse);
      expect(barrelSymbols.contains('curriculum_validation.dart'), isFalse);
    });
  });
}

/// An [AssetBundle] backed by a single in-memory string; `null` payload
/// simulates a missing asset.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._payload);

  final String? _payload;

  @override
  Future<ByteData> load(String key) async {
    final payload = _payload;
    if (payload == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(payload)));
  }
}
