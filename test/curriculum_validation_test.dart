import 'package:catear/curriculo/domain/curriculum_validation.dart';
import 'package:catear/curriculo/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/curriculum_fixtures.dart';

/// Direct unit tests for the shared validation — `validateCatalogStructure`
/// (everything `load()` enforces) and `checkFadingAndOrder` (R1/R2/R3, the
/// build gate's content invariants). `test/check_curriculum_test.dart` keeps
/// only a couple of subprocess smoke tests on top of this.
void main() {
  List<CurriculumViolation> struct(
    void Function(Map<String, dynamic> json) mutate,
  ) => validateCatalogStructure(catalogFixture(mutate));

  List<CurriculumViolation> fading(
    void Function(Map<String, dynamic> json) mutate,
  ) => checkFadingAndOrder(catalogFixture(mutate));

  void expectViolation(
    List<CurriculumViolation> violations, {
    String? path,
    Pattern? pathContains,
    Pattern? messageContains,
    ViolationKind? kind,
  }) {
    final hit = violations.any(
      (v) =>
          (path == null || v.path == path) &&
          (pathContains == null || v.path.contains(pathContains)) &&
          (messageContains == null || v.message.contains(messageContains)) &&
          (kind == null || v.kind == kind),
    );
    expect(
      hit,
      isTrue,
      reason: 'no matching violation in:\n${violations.join('\n')}',
    );
  }

  // ---- structural: the real catalog is clean --------------------------

  test('validateCatalogStructure: committed catalog has no violations', () {
    expect(validateCatalogStructure(realCatalogJson), isEmpty);
  });

  // ---- root shape ----------------------------------------------------

  group('root shape', () {
    test('array root', () {
      expectViolation(validateCatalogStructure(<dynamic>[]), path: '<root>');
    });
    test('scalar root (int)', () {
      expectViolation(validateCatalogStructure(42), path: '<root>');
    });
    test('scalar root (null)', () {
      expectViolation(validateCatalogStructure(null), path: '<root>');
    });
  });

  // ---- schemaVersion ------------------------------------------------

  group('schemaVersion', () {
    test('missing', () {
      expectViolation(
        struct((j) => j.remove('schemaVersion')),
        path: 'schemaVersion',
      );
    });
    test('wrong number', () {
      expectViolation(
        struct((j) => j['schemaVersion'] = 2),
        path: 'schemaVersion',
      );
    });
    test('string "1"', () {
      expectViolation(
        struct((j) => j['schemaVersion'] = '1'),
        path: 'schemaVersion',
      );
    });
  });

  // ---- stages / errorTypes presence -------------------------------

  group('top-level lists', () {
    test('stages key absent', () {
      expectViolation(struct((j) => j.remove('stages')), path: 'stages');
    });
    test('stages empty', () {
      expectViolation(struct((j) => j['stages'] = <dynamic>[]), path: 'stages');
    });
    test('errorTypes key absent', () {
      expectViolation(
        struct((j) => j.remove('errorTypes')),
        path: 'errorTypes',
      );
    });
    test('errorTypes empty', () {
      expectViolation(
        struct((j) => j['errorTypes'] = <dynamic>[]),
        path: 'errorTypes',
      );
    });
  });

  // ---- errorTypes vs the ErrorType enum ---------------------------

  group('errorTypes sync', () {
    test('missing an id -> malformed, names the id', () {
      expectViolation(
        struct((j) => (j['errorTypes'] as List).remove('TT')),
        path: 'errorTypes',
        messageContains: 'TT',
        kind: ViolationKind.malformed,
      );
    });
    test('an unknown extra id -> unknownValue', () {
      expectViolation(
        struct((j) => (j['errorTypes'] as List).add('P9')),
        pathContains: 'errorTypes',
        kind: ViolationKind.unknownValue,
      );
    });
  });

  // ---- *Catalog entry shape (I/O matrix: field missing / wrong type) --

  group('catalog entry shape', () {
    test('intervalCatalog semitones as string', () {
      expectViolation(
        struct((j) => (j['intervalCatalog'] as List).first['semitones'] = 'x'),
        pathContains: 'intervalCatalog[0].semitones',
      );
    });
    test('intervalCatalog entry missing nameUi', () {
      expectViolation(
        struct((j) => (j['intervalCatalog'] as List).first.remove('nameUi')),
        pathContains: 'intervalCatalog[0].nameUi',
      );
    });
    test('chordCatalog entry missing inversion', () {
      expectViolation(
        struct((j) => (j['chordCatalog'] as List).first.remove('inversion')),
        pathContains: 'chordCatalog[0].inversion',
      );
    });
    test('scaleCatalog steps not a list', () {
      expectViolation(
        struct((j) => (j['scaleCatalog'] as List).first['steps'] = 7),
        pathContains: 'scaleCatalog[0].steps',
      );
    });
    test('cadenceCatalog entry missing degrees', () {
      expectViolation(
        struct((j) => (j['cadenceCatalog'] as List).first.remove('degrees')),
        pathContains: 'cadenceCatalog[0].degrees',
      );
    });
    test('duplicate id within a catalog', () {
      expectViolation(
        struct(
          (j) => (j['chordCatalog'] as List).add({
            'id': 'major',
            'nameUi': 'dup',
            'intervals': [4, 7],
            'inversion': 0,
          }),
        ),
        pathContains: 'chordCatalog',
        messageContains: 'duplicate id',
      );
    });
  });

  // ---- stage-level ------------------------------------------------

  group('stage fields', () {
    test('duplicate stageId', () {
      expectViolation(
        struct((j) => stagesOf(j)[1]['stageId'] = stagesOf(j)[0]['stageId']),
        messageContains: 'duplicate stageId',
      );
    });
    test('order not an int', () {
      expectViolation(
        struct((j) => stagesOf(j).first['order'] = 'first'),
        pathContains: '.order',
      );
    });
    test('order missing', () {
      expectViolation(
        struct((j) => stagesOf(j).first.remove('order')),
        pathContains: '.order',
      );
    });
    test('scaffoldIntensity above 1.0', () {
      expectViolation(
        struct((j) => stagesOf(j).first['scaffoldIntensity'] = 1.5),
        pathContains: '.scaffoldIntensity',
      );
    });
    test('scaffoldIntensity below 0.0', () {
      expectViolation(
        struct((j) => stagesOf(j).first['scaffoldIntensity'] = -0.1),
        pathContains: '.scaffoldIntensity',
      );
    });
    test('unknown timbreScaffold -> unknownValue', () {
      expectViolation(
        struct((j) => stagesOf(j).first['timbreScaffold'] = 'warble'),
        pathContains: '.timbreScaffold',
        kind: ViolationKind.unknownValue,
      );
    });
    test('empty exercises', () {
      expectViolation(
        struct((j) => stagesOf(j).first['exercises'] = <dynamic>[]),
        pathContains: '.exercises',
      );
    });
    test('exercises missing', () {
      expectViolation(
        struct((j) => stagesOf(j).first.remove('exercises')),
        pathContains: '.exercises',
      );
    });
  });

  // ---- exercise-level -------------------------------------------

  group('exercise fields', () {
    test('unknown exerciseType -> unknownValue', () {
      expectViolation(
        struct(
          (j) => exercisesOf(stagesOf(j).first).first['exerciseType'] = 'arp',
        ),
        kind: ViolationKind.unknownValue,
        pathContains: '.exerciseType',
      );
    });
    test('interval missing direction', () {
      expectViolation(
        struct((j) => exercisesOf(stagesOf(j).first).first.remove('direction')),
        pathContains: '.direction',
      );
    });
    test('direction on a chord exercise', () {
      expectViolation(
        struct(
          (j) =>
              exercisesOf(stageById(j, 's-acordes')).first['direction'] = 'asc',
        ),
        pathContains: '.direction',
      );
    });
    test('unknown direction -> unknownValue', () {
      expectViolation(
        struct((j) => exercisesOf(stagesOf(j).first).first['direction'] = 'up'),
        pathContains: '.direction',
        kind: ViolationKind.unknownValue,
      );
    });
    test('requiresVoice on a non-resolution exercise', () {
      expectViolation(
        struct(
          (j) => exercisesOf(stagesOf(j).first).first['requiresVoice'] = true,
        ),
        pathContains: '.requiresVoice',
      );
    });
    test('resolution without requiresVoice', () {
      expectViolation(
        struct(
          (j) =>
              exercisesOf(stageById(j, 's-resolucao')).first
                  .remove('requiresVoice'),
        ),
        pathContains: '.requiresVoice',
      );
    });
    test('audioSampleRefs empty', () {
      expectViolation(
        struct(
          (j) => exercisesOf(stagesOf(j).first).first['audioSampleRefs'] =
              <dynamic>[],
        ),
        pathContains: 'audioSampleRefs',
      );
    });
    test('audioSampleRefs token breaks the regex', () {
      expectViolation(
        struct(
          (j) => exercisesOf(stagesOf(j).first).first['audioSampleRefs'] = [
            'Sax C4',
          ],
        ),
        pathContains: 'audioSampleRefs',
      );
    });
    test('audioSampleRefs a bare string, not a list', () {
      expectViolation(
        struct(
          (j) => exercisesOf(stagesOf(j).first).first['audioSampleRefs'] =
              'sax_c4',
        ),
        pathContains: 'audioSampleRefs',
      );
    });
  });

  group('orphan exercise id in each *Catalog -> unknownValue', () {
    test('intervalCatalog', () {
      expectViolation(
        struct(
          (j) => exercisesOf(stageById(j, 's-consonancias')).first['interval'] =
              'P9',
        ),
        pathContains: 's-consonancias',
        messageContains: 'intervalCatalog',
        kind: ViolationKind.unknownValue,
      );
    });
    test('chordCatalog', () {
      expectViolation(
        struct(
          (j) => exercisesOf(stageById(j, 's-acordes')).first['chordQuality'] =
              'sus4',
        ),
        messageContains: 'chordCatalog',
        kind: ViolationKind.unknownValue,
      );
    });
    test('scaleCatalog', () {
      expectViolation(
        struct(
          // Deliberately not a mode name at all. 'dorian' used to stand here
          // and Story 1.4b promoted it into scaleCatalog, breaking this probe;
          // 'phrygian' would only defer the same trap to the next expansion.
          (j) => exercisesOf(stageById(j, 's-escalas')).first['scaleType'] =
              'not-a-scale-id',
        ),
        messageContains: 'scaleCatalog',
        kind: ViolationKind.unknownValue,
      );
    });
    test('cadenceCatalog', () {
      expectViolation(
        struct(
          (j) => exercisesOf(stageById(j, 's-resolucao')).first['cadence'] =
              'deceptive',
        ),
        messageContains: 'cadenceCatalog',
        kind: ViolationKind.unknownValue,
      );
    });
  });

  // ---- checkFadingAndOrder: R1 / R2 / R3 -----------------------

  group('checkFadingAndOrder', () {
    test('committed catalog has no R1/R2/R3 violations', () {
      expect(checkFadingAndOrder(realCatalogJson), isEmpty);
    });

    test('R1 — duplicate order fails', () {
      final v = fading((j) => stageById(j, 's-tercas')['order'] = 2);
      expectViolation(v, messageContains: 'R1');
    });

    test('R1 — a gap in order ([1,3,5]-style) is allowed', () {
      // s-tritono is order 10; bump it to 12 -> orders stay unique, one gap.
      final v = fading((j) => stageById(j, 's-tritono')['order'] = 12);
      expect(
        v.where((x) => x.message.contains('R1')),
        isEmpty,
        reason: v.join('\n'),
      );
    });

    test('R1 — a shuffled stages array with intact unique orders passes', () {
      final v = fading((j) => j['stages'] = stagesOf(j).reversed.toList());
      expect(v.where((x) => x.message.contains('R1')), isEmpty);
    });

    test(
      'R2 — scaffoldIntensity rising across the ordered subsequence fails',
      () {
        final v = fading(
          (j) => stageById(j, 's-tritono')['scaffoldIntensity'] = 1.0,
        );
        expectViolation(v, messageContains: 'R2', pathContains: 's-tritono');
      },
    );

    test('R2 — a null hole in the middle is ignored (not treated as 0.0)', () {
      // Drop the scaffold from a mid stage; the fade around it stays valid.
      final v = fading(
        (j) => stageById(j, 's-segundas').remove('scaffoldIntensity'),
      );
      expect(v.where((x) => x.message.contains('R2')), isEmpty);
    });

    test('R3 — clean timbre after vibrato fails', () {
      final v = fading(
        (j) => stageById(j, 's-tritono')['timbreScaffold'] = 'clean',
      );
      expectViolation(v, messageContains: 'R3');
    });
  });

  // ---- enum parsers ---------------------------------------------

  group('enum fromJson throws unknownValue', () {
    test('ErrorType', () {
      expect(
        () => ErrorType.fromJson('errorTypes', 'nope'),
        throwsA(isA<Exception>()),
      );
    });
    test('Direction / TimbreScaffold / ExerciseType', () {
      expect(() => Direction.fromJson('d', 'x'), throwsA(isA<Exception>()));
      expect(
        () => TimbreScaffold.fromJson('t', 'x'),
        throwsA(isA<Exception>()),
      );
      expect(() => ExerciseType.fromJson('e', 'x'), throwsA(isA<Exception>()));
    });
  });
}
