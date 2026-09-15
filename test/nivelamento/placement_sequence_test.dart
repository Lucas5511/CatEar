import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/nivelamento/nivelamento.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Story 1.9 — the levelling's pure rules against the real `catalog_v1.json`:
/// the fixed sequence, the deliberately easy opener, the level rule and the
/// human names. No widget, no notifier, no database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Curriculum> loadReal() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(curriculoRepositoryProvider).load();
  }

  ExerciseAttempt attempt({required bool correct}) => ExerciseAttempt(
    exerciseType: ExerciseType.interval,
    wasCorrect: correct,
    reactionTimeMs: 100,
    errorType: correct ? null : ErrorType.farMiss,
  );

  List<ExerciseAttempt> attempts(List<bool> pattern) => [
    for (final correct in pattern) attempt(correct: correct),
  ];

  group('the sequence', () {
    test('is the seven ascending intervals, one per interval stage, in the '
        'decided order (P8, M3, M2, P4, M6, m7, TT)', () async {
      final loop = placementLoop(await loadReal());

      expect(loop.map((q) => q.answer.id).toList(), [
        'P8',
        'M3',
        'M2',
        'P4',
        'M6',
        'm7',
        'TT',
      ]);
      expect(placementSequence.map((s) => s.stageId).toList(), [
        's-consonancias',
        's-tercas',
        's-segundas',
        's-quarta',
        's-sextas',
        's-setimas',
        's-tritono',
      ]);
      for (final question in loop) {
        expect(question.type, ExerciseType.interval);
        expect(question.variantKey, 'asc', reason: 'ascending, no root');
      }
    });

    test('plays the catalog refs verbatim — no variation, nothing to record '
        'in the variation history', () async {
      final curriculum = await loadReal();
      final loop = placementLoop(curriculum);

      for (var i = 0; i < loop.length; i++) {
        final step = placementSequence[i];
        final stage = curriculum.stages.singleWhere(
          (s) => s.stageId == step.stageId,
        );
        final exercise = stage.exercises
            .whereType<IntervalExercise>()
            .singleWhere(
              (e) =>
                  e.interval.id == step.intervalId &&
                  e.direction == Direction.asc,
            );
        expect(loop[i].audioSampleRefs, exercise.audioSampleRefs);
        expect(
          loop[i].variant,
          isNull,
          reason: 'refs verbatim, no transposition',
        );
        expect(loop[i], questionFor(exercise));
      }
      // The octave the learner hears first: C4 up to C5, as the catalog wrote it.
      expect(loop.first.audioSampleRefs, ['sax_c4', 'sax_c5']);
    });

    test('a catalog missing a step surfaces as a NivelamentoError, not a '
        'card', () async {
      final real = await loadReal();
      // Every stage but the tritone's.
      final truncated = Curriculum(
        schemaVersion: real.schemaVersion,
        errorTypes: real.errorTypes,
        stages: [
          for (final stage in real.stages)
            if (stage.stageId != 's-tritono') stage,
        ],
      );

      expect(
        () => placementLoop(truncated),
        throwsA(
          isA<PlacementExerciseMissing>().having(
            (e) => e.step.stageId,
            'step.stageId',
            's-tritono',
          ),
        ),
      );
    });
  });

  group('the options', () {
    test('the first card is a rising octave whose distractors are the three '
        'farthest intervals — so the unison is among them', () async {
      final curriculum = await loadReal();
      final loop = placementLoop(curriculum);
      final pool = placementPool(curriculum);

      final options = placementOptionsFor(loop, pool, 0);
      expect(options, hasLength(4));
      expect(options.map((o) => o.id).toSet(), {'P8', 'P1', 'm2', 'M2'});
      expect(loop.first.answer.id, 'P8');
    });

    test('every later card takes the practice\'s three closest', () async {
      final curriculum = await loadReal();
      final loop = placementLoop(curriculum);
      final pool = placementPool(curriculum);

      for (var i = 1; i < loop.length; i++) {
        final expected = answerOptionsForQuestion(
          loop[i],
          pool,
          seed: loop[i].optionSeed(i),
        );
        expect(placementOptionsFor(loop, pool, i), expected);
      }
      // Spot check: the major third's neighbours, not the far ends.
      expect(placementOptionsFor(loop, pool, 1).map((o) => o.id).toSet(), {
        'M3',
        'm3',
        'P4',
        'M2',
      });
    });

    test('the pool is the 13 intervals only', () async {
      final pool = placementPool(await loadReal());
      expect(pool.keys, [ExerciseType.interval]);
      expect(pool[ExerciseType.interval], hasLength(13));
    });

    test('farthestOptionsFor: answer always included, ranking by distance '
        'descending with ties on id, order deterministic by seed', () {
      AnswerOption o(String id, int semis) =>
          AnswerOption(id: id, nameUi: id, semitoneProfile: [semis]);
      final pool = [o('a', 0), o('b', 3), o('c', 6), o('d', 9), o('e', 12)];
      final answer = o('c', 6);

      final options = farthestOptionsFor(answer, pool, seed: 7);
      expect(options, hasLength(4));
      expect(options, contains(answer));
      // Distances from 6: a=6, e=6, b=3, d=3 -> a, e, then b (id tie-break).
      expect(options.map((x) => x.id).toSet(), {'c', 'a', 'e', 'b'});
      expect(farthestOptionsFor(answer, pool, seed: 7), options);

      // A short pool: as many as it has, the answer still there.
      final short = farthestOptionsFor(answer, [o('a', 0)], seed: 1);
      expect(short.map((x) => x.id).toSet(), {'c', 'a'});
    });
  });

  group('the level rule', () {
    test('is the stage of the first step missed', () {
      expect(
        placementOutcomeFor(
          attempts([true, true, false, true, false, true, true]),
        ),
        const PlacementOutcome(stageId: 's-segundas', correctCount: 5),
      );
      expect(
        placementOutcomeFor(
          attempts([true, true, true, true, true, true, false]),
        ),
        const PlacementOutcome(stageId: 's-tritono', correctCount: 6),
      );
    });

    test('all seven right -> the last stage', () {
      expect(
        placementOutcomeFor(attempts(List.filled(7, true))),
        const PlacementOutcome(stageId: 's-tritono', correctCount: 7),
      );
    });

    test('zero right -> the first stage, and the count says so', () {
      expect(
        placementOutcomeFor(attempts(List.filled(7, false))),
        const PlacementOutcome(stageId: 's-consonancias', correctCount: 0),
      );
    });

    test('nothing answered -> the first stage', () {
      expect(
        placementOutcomeFor(const []),
        const PlacementOutcome(stageId: 's-consonancias', correctCount: 0),
      );
    });

    test('a short run never places past what was asked', () {
      expect(
        placementOutcomeFor(attempts([true, true])),
        const PlacementOutcome(stageId: 's-tercas', correctCount: 2),
      );
    });
  });

  group('the names', () {
    test('every stage of the sequence has a human name', () {
      expect(placementSequence.map((s) => s.nameUi).toList(), [
        'Consonâncias',
        'Terças',
        'Segundas',
        'Quarta',
        'Sextas',
        'Sétimas',
        'Trítono',
      ]);
      expect(stageNameFor('s-quarta'), 'Quarta');
      expect(
        const PlacementOutcome(
          stageId: 's-setimas',
          correctCount: 5,
        ).stageNameUi,
        'Sétimas',
      );
    });

    test('an unknown stage falls back to its id rather than throwing', () {
      expect(stageNameFor('s-escalas'), 's-escalas');
    });
  });
}
