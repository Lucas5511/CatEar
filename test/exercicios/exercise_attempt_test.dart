import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written `steps`, used only by the unit cases below that need a mode in
/// isolation. These are NOT the shipping catalog — the group
/// "against the real catalog_v1.json" loads that through
/// `curriculoRepositoryProvider`, because editing `scaleCatalog[].steps` would
/// otherwise silently degrade every scale error to `far-miss` with a green CI.
const _steps = {
  'major': [2, 2, 1, 2, 2, 2, 1],
  'natural_minor': [2, 1, 2, 2, 1, 2, 2],
  'dorian': [2, 1, 2, 2, 2, 1, 2],
  'mixolydian': [2, 2, 1, 2, 2, 1, 2],
};

/// The v1 `chordCatalog` semitone sets.
const _chords = {
  'major': [4, 7],
  'minor': [3, 7],
  'diminished': [3, 6],
  'augmented': [4, 8],
};

/// Options are built the way the app builds them — through `questionFor` — so
/// the tests cover the projection too, not a hand-rolled parallel one.
AnswerOption _interval(String id, int semitones) => questionFor(
  IntervalExercise(
    interval: IntervalSpec(
      id: id,
      semitones: semitones,
      nameUi: id,
      abbr: id,
      quality: 'x',
    ),
    direction: Direction.asc,
    audioSampleRefs: const ['a'],
  ),
).answer;

AnswerOption _scale(String id) => questionFor(
  ScaleExercise(
    scale: ScaleSpec(id: id, nameUi: id, steps: _steps[id]!),
    direction: Direction.asc,
    audioSampleRefs: const ['a'],
  ),
).answer;

AnswerOption _chord(String id) => questionFor(
  ChordExercise(
    chord: ChordSpec(id: id, nameUi: id, intervals: _chords[id]!, inversion: 0),
    audioSampleRefs: const ['a'],
  ),
).answer;

void main() {
  // Needed by the real-catalog group below: without it `rootBundle` cannot
  // resolve assets/curriculum/catalog_v1.json.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('value contract', () {
    test('== / hashCode keyed on all four fields; toString', () {
      const a = ExerciseAttempt(
        exerciseType: ExerciseType.interval,
        wasCorrect: false,
        errorType: ErrorType.majorThird,
        reactionTimeMs: 1200,
      );
      const b = ExerciseAttempt(
        exerciseType: ExerciseType.interval,
        wasCorrect: false,
        errorType: ErrorType.majorThird,
        reactionTimeMs: 1200,
      );
      const differsRt = ExerciseAttempt(
        exerciseType: ExerciseType.interval,
        wasCorrect: false,
        errorType: ErrorType.majorThird,
        reactionTimeMs: 1201,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(differsRt)));
      expect(
        a.toString(),
        'ExerciseAttempt(exerciseType: ExerciseType.interval, '
        'wasCorrect: false, errorType: ErrorType.majorThird, '
        'reactionTimeMs: 1200)',
      );
    });

    test('a correct attempt with a non-null errorType is rejected', () {
      expect(
        () => ExerciseAttempt(
          exerciseType: ExerciseType.interval,
          wasCorrect: true,
          errorType: ErrorType.p5,
          reactionTimeMs: 1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a non-positive reaction time is rejected', () {
      expect(
        () => ExerciseAttempt(
          exerciseType: ExerciseType.interval,
          wasCorrect: true,
          reactionTimeMs: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ExerciseAttempt.forAnswer — interval', () {
    final m3 = _interval('M3', 4);

    test('correct answer -> wasCorrect true, errorType null', () {
      final attempt = ExerciseAttempt.forAnswer(
        exerciseType: ExerciseType.interval,
        answer: m3,
        picked: m3,
        reactionTimeMs: 900,
      );
      expect(attempt.wasCorrect, isTrue);
      expect(attempt.errorType, isNull);
      expect(attempt.exerciseType, ExerciseType.interval);
      expect(attempt.reactionTimeMs, 900);
    });

    test(
      'wrong answer -> errorType is the interval ErrorType whose id == picked',
      () {
        final attempt = ExerciseAttempt.forAnswer(
          exerciseType: ExerciseType.interval,
          answer: m3,
          picked: _interval('P5', 7),
          reactionTimeMs: 1500,
        );
        expect(attempt.wasCorrect, isFalse);
        expect(attempt.errorType, ErrorType.p5);
        expect(attempt.errorType!.id, 'P5');
      },
    );

    test('every P1..P8 token resolves 1:1', () {
      const ids = [
        'P1', 'm2', 'M2', 'm3', 'M3', 'P4', 'TT', 'P5', 'm6', 'M6', 'm7', 'M7',
        'P8', //
      ];
      for (final id in ids) {
        final resolved = ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.interval,
          answer: m3,
          picked: _interval(id, 0),
        );
        expect(resolved.id, id);
      }
    });

    test('an interval id with no ErrorType is a far-miss, never a throw', () {
      // A v2 catalog interval the taxonomy has not caught up with. This runs
      // mid-session, outside any AsyncValue.error — it must not take the
      // screen down.
      expect(
        ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.interval,
          answer: m3,
          picked: _interval('ZZ', 99),
        ),
        ErrorType.farMiss,
      );
    });
  });

  group('ExerciseAttempt.forAnswer — chord', () {
    test('picking the diminished triad for a major one is `diminished`', () {
      final attempt = ExerciseAttempt.forAnswer(
        exerciseType: ExerciseType.chord,
        answer: _chord('major'),
        picked: _chord('diminished'),
        reactionTimeMs: 700,
      );
      expect(attempt.exerciseType, ExerciseType.chord);
      expect(attempt.errorType, ErrorType.diminished);
    });

    test('every chordCatalog id resolves to its quality ErrorType', () {
      const expected = {
        'major': ErrorType.major,
        'minor': ErrorType.minor,
        'diminished': ErrorType.diminished,
        'augmented': ErrorType.augmented,
      };
      for (final entry in expected.entries) {
        expect(
          ExerciseAttempt.errorTypeFor(
            exerciseType: ExerciseType.chord,
            answer: _chord('minor'),
            picked: _chord(entry.key),
          ),
          entry.value,
        );
      }
    });
  });

  group('ExerciseAttempt.forAnswer — scale', () {
    test('one altered degree names the degree', () {
      // major vs mixolydian differ only on the 7th.
      expect(
        ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.scale,
          answer: _scale('major'),
          picked: _scale('mixolydian'),
        ),
        ErrorType.setimaAlterada,
      );
      // mixolydian vs dorian differ only on the 3rd.
      expect(
        ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.scale,
          answer: _scale('mixolydian'),
          picked: _scale('dorian'),
        ),
        ErrorType.tercaAlterada,
      );
      // dorian vs natural minor differ only on the 6th.
      expect(
        ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.scale,
          answer: _scale('dorian'),
          picked: _scale('natural_minor'),
        ),
        ErrorType.sextaAlterada,
      );
    });

    test('unequal profile lengths are a far-miss by decision', () {
      // `degree = index + 2` only holds while both profiles describe the same
      // number of degrees; a pentatonic (Story 1.8) would otherwise be filed
      // under the wrong degree.
      final sevenNote = _scale('major');
      final pentatonic = questionFor(
        ScaleExercise(
          scale: const ScaleSpec(
            id: 'pentatonic',
            nameUi: 'pentatônica',
            steps: [2, 2, 3, 2, 3],
          ),
          direction: Direction.asc,
          audioSampleRefs: const ['sax_c4'],
        ),
      ).answer;
      expect(
        ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.scale,
          answer: sevenNote,
          picked: pentatonic,
        ),
        ErrorType.farMiss,
      );
    });

    test('several altered degrees is a far-miss', () {
      // major vs natural minor differ on the 3rd, 6th and 7th.
      expect(
        ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.scale,
          answer: _scale('major'),
          picked: _scale('natural_minor'),
        ),
        ErrorType.farMiss,
      );
    });

    test('the scale/chord `major` id collision never crosses over', () {
      // `scaleCatalog` and `chordCatalog` both carry an id of "major", and
      // ErrorType.major means *chord quality*. A global lookup by id would
      // file this scale mistake as a chord mistake — Story 1.6 would then
      // explain the wrong concept.
      final resolved = ExerciseAttempt.errorTypeFor(
        exerciseType: ExerciseType.scale,
        answer: _scale('dorian'),
        picked: _scale('major'),
      );
      expect(resolved, isNot(ErrorType.major));
      expect(chordErrorTypes, isNot(contains(resolved)));
      expect(intervalErrorTypes, isNot(contains(resolved)));
    });

    test('the symmetric collision holds for chords too', () {
      expect(
        ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.chord,
          answer: _chord('minor'),
          picked: _chord('major'),
        ),
        ErrorType.major,
        reason: 'a chord "major" *is* the chord-quality ErrorType',
      );
    });
  });

  test('resolution attempts resolve to far-miss, never a throw', () {
    // Resolution is sung, not tapped (Epic 3); the taxonomy has no entry.
    expect(
      ExerciseAttempt.errorTypeFor(
        exerciseType: ExerciseType.resolution,
        answer: questionFor(
          const ResolutionExercise(
            cadence: CadenceSpec(
              id: 'authentic',
              nameUi: 'cadência perfeita',
              degrees: ['V', 'I'],
            ),
            audioSampleRefs: ['a'],
          ),
        ).answer,
        picked: questionFor(
          const ResolutionExercise(
            cadence: CadenceSpec(
              id: 'plagal',
              nameUi: 'cadência plagal',
              degrees: ['IV', 'I'],
            ),
            audioSampleRefs: ['a'],
          ),
        ).answer,
      ),
      ErrorType.farMiss,
    );
  });

  test('degreesFromSteps turns steps into offsets above the tonic', () {
    expect(degreesFromSteps(_steps['major']!), [2, 4, 5, 7, 9, 11, 12]);
    expect(degreesFromSteps(_steps['natural_minor']!), [2, 3, 5, 7, 8, 10, 12]);
    expect(degreesFromSteps(const []), isEmpty);
  });

  group('against the real catalog_v1.json', () {
    // The taxonomy is a function of the catalog's `steps`, not of an id, so
    // hand-copied fixtures cannot guard it: editing `mixolydian.steps` in the
    // shipping catalog turns every major-vs-mixolydian mistake into a generic
    // `far-miss`, and Story 1.6 then explains the wrong concept. Verified: that
    // edit passes `check_curriculum` and the whole suite without this group.
    Future<List<AnswerOption>> poolOf(ExerciseType type) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final curriculum = await container
          .read(curriculoRepositoryProvider)
          .load();
      return practicePool(curriculum, types: {type});
    }

    test(
      'real scale modes resolve to the degree that separates them',
      () async {
        final pool = await poolOf(ExerciseType.scale);
        AnswerOption of(String id) => pool.firstWhere((o) => o.id == id);

        ErrorType resolve(String answer, String picked) =>
            ExerciseAttempt.errorTypeFor(
              exerciseType: ExerciseType.scale,
              answer: of(answer),
              picked: of(picked),
            );

        expect(resolve('major', 'mixolydian'), ErrorType.setimaAlterada);
        expect(resolve('mixolydian', 'dorian'), ErrorType.tercaAlterada);
        expect(resolve('dorian', 'natural_minor'), ErrorType.sextaAlterada);
        expect(resolve('major', 'natural_minor'), ErrorType.farMiss);
      },
    );

    test('every real interval and chord id resolves off far-miss', () async {
      for (final o in await poolOf(ExerciseType.interval)) {
        expect(
          ExerciseAttempt.errorTypeFor(
            exerciseType: ExerciseType.interval,
            answer: o,
            picked: o,
          ),
          isNot(ErrorType.farMiss),
          reason:
              'interval "${o.id}" has no ErrorType — it would file silently',
        );
      }
      for (final o in await poolOf(ExerciseType.chord)) {
        expect(
          ExerciseAttempt.errorTypeFor(
            exerciseType: ExerciseType.chord,
            answer: o,
            picked: o,
          ),
          isNot(ErrorType.farMiss),
          reason: 'chord "${o.id}" has no ErrorType — it would file silently',
        );
      }
    });
  });
}
