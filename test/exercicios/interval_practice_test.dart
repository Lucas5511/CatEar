import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixed loop (`practiceLoop`) and distractor pool (`practicePool`) against
/// the real `catalog_v1.json`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Curriculum> loadReal() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(curriculoRepositoryProvider).load();
  }

  test('loop is every IntervalExercise in stage order, nothing else', () async {
    final loop = practiceLoop(await loadReal());

    // 23 interval exercises across the 7 interval stages of v1.
    expect(loop.length, 23);
    expect(loop.every((q) => q.type == ExerciseType.interval), isTrue);
    expect(loop.first.answer.id, 'P1');
    expect(loop.first.variantKey, Direction.asc);
    expect(loop.last.answer.id, 'TT');
    expect(loop.last.variantKey, Direction.desc);
  });

  test('a sung exercise stays out even when its type is named', () async {
    // `requiresVoice` is the second half of the filter. Resolution exercises
    // are sung (Epic 3) and have no tap-to-answer surface, so naming their
    // type must not put them in the loop.
    final curriculum = await loadReal();
    expect(
      curriculum.stages.expand((s) => s.exercises).any((e) => e.requiresVoice),
      isTrue,
      reason: 'the catalog does contain a sung exercise',
    );
    expect(
      practiceLoop(curriculum, types: const {ExerciseType.resolution}),
      isEmpty,
    );
  });

  test('the pool keys dedupe on (type, id), not on the bare id', () async {
    // `chordCatalog` and `scaleCatalog` both carry an `id: "major"`. A bare-id
    // pool would collapse them, and `_OptionButton` compares ids — so a scale
    // button would highlight as correct for a chord answer.
    final curriculum = await loadReal();
    final mixed = practicePool(
      curriculum,
      types: const {ExerciseType.chord, ExerciseType.scale},
    );
    expect(mixed.where((o) => o.id == 'major').length, 2);
    expect(mixed.length, 8, reason: '4 chord qualities + 4 scale modes');
  });

  test('loop excludes chord / scale / resolution exercises', () async {
    final curriculum = await loadReal();
    final loop = practiceLoop(curriculum);
    final allExercises = curriculum.stages.expand((s) => s.exercises).toList();

    // Content, not just cardinality: a loop of 23 questions built from the
    // wrong exercises would pass a bare length check.
    final stages = [...curriculum.stages]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.stageId.compareTo(b.stageId);
      });
    final expectedIds = [
      for (final stage in stages)
        for (final e in stage.exercises)
          if (e is IntervalExercise) e.interval.id,
    ];
    expect(loop.map((q) => q.answer.id).toList(), expectedIds);
    expect(loop.every((q) => q.type == ExerciseType.interval), isTrue);
    expect(
      allExercises.any((e) => e is! IntervalExercise),
      isTrue,
      reason: 'the catalog does contain non-interval exercises',
    );
  });

  test('loop honours stage.order even if stages come pre-sorted', () async {
    final loop = practiceLoop(await loadReal());
    // P1/P8/P5 (order 1) precede the thirds (order 3) precede the tritone (10).
    final ids = loop.map((q) => q.answer.id).toList();
    expect(ids.indexOf('P1') < ids.indexOf('M3'), isTrue);
    expect(ids.indexOf('M3') < ids.indexOf('TT'), isTrue);
  });

  test('pool is the 13 distinct answer options, first-seen order', () async {
    final pool = practicePool(await loadReal());
    // 13 distinct intervals in v1. This is a loop invariant, not a catalog
    // fact: it must not move because a new exercise type was added — if it
    // does, the practice loop has leaked past `defaultPracticeTypes`.
    expect(pool.length, 13);
    expect(pool.map((s) => s.id).toSet(), {
      'P1', 'm2', 'M2', 'm3', 'M3', 'P4', 'TT', 'P5', 'm6', 'M6', 'm7', 'M7',
      'P8', //
    });
    expect(pool.first.id, 'P1', reason: 'first exercise is P1');
    // No duplicates.
    expect(pool.map((s) => s.id).toList().toSet().length, pool.length);
  });

  test('the loop shape is type-agnostic: chord and scale flow through it '
      'unchanged (Story 1.5 flips the default, not the machinery)', () async {
    final curriculum = await loadReal();

    final chords = practiceLoop(curriculum, types: const {ExerciseType.chord});
    expect(chords, isNotEmpty);
    expect(chords.every((q) => q.type == ExerciseType.chord), isTrue);
    expect(chords.first.prompt, 'Que acorde é este?');
    expect(
      practicePool(
        curriculum,
        types: const {ExerciseType.chord},
      ).map((o) => o.id).toSet(),
      {'major', 'minor', 'diminished', 'augmented'},
    );

    final scales = practiceLoop(curriculum, types: const {ExerciseType.scale});
    expect(scales, isNotEmpty);
    expect(scales.every((q) => q.type == ExerciseType.scale), isTrue);
    expect(scales.first.prompt, 'Que escala é esta?');
    expect(
      practicePool(
        curriculum,
        types: const {ExerciseType.scale},
      ).map((o) => o.id).toSet(),
      {'major', 'natural_minor', 'dorian', 'mixolydian'},
    );

    // The default is still intervals only — the loop must not have leaked.
    expect(practiceLoop(curriculum).length, 23);
  });

  test('GOLDEN: interval option selection and ordering are frozen', () async {
    // The story's central claim is "comportamento de intervalo idêntico", and a
    // determinism-only assertion cannot guard it: any seed formula is
    // deterministic for a fixed seed. Two goldens, because only one of the two
    // halves is stable across runs:
    //
    //  * ORDERING, with an explicit seed — this is the ranking + shuffle, and
    //    it is what a refactor of `answerOptionsFor` would move.
    //  * SELECTION, through the real `optionSeed` — the option *set* per loop
    //    position. The order there cannot be frozen: `optionSeed` hashes a
    //    `Direction` enum, whose hashCode is identity-based and therefore
    //    re-randomised every run (measured 2026-09-05: the same position
    //    yielded seeds 489118127 / 15087377 / 409236786 across three runs).
    //    That instability predates this story (Story 1.4 hashed
    //    `exercise.direction` the same way) and is filed in deferred-work.md.
    const orderedBySeedIndex = <String>[
      'm2,P1,M2,m3',
      'm7,M7,M6,P8',
      'M6,m6,P5,TT',
      'P4,M3,m3,M2',
      'M2,P4,M3,m3',
      'M2,M3,P4,m3',
      'm3,P4,M3,M2',
      'm2,M3,m3,M2',
      'M3,m3,m2,M2',
      'm2,M2,P1,m3',
      'm2,P1,M2,m3',
      'P5,M3,P4,TT',
      'P5,P4,TT,M3',
      'M6,m7,M7,m6',
      'm7,m6,M6,M7',
      'm6,TT,P5,M6',
      'P5,TT,m6,M6',
      'M6,P8,M7,m7',
      'P8,m7,M7,M6',
      'M6,M7,P8,m7',
      'm7,M7,M6,P8',
      'P4,P5,TT,M3',
      'M3,P5,TT,P4',
    ];

    final curriculum = await loadReal();
    final loop = practiceLoop(curriculum);
    final pool = practicePool(curriculum);
    expect(loop.length, orderedBySeedIndex.length);

    for (var i = 0; i < loop.length; i++) {
      expect(
        answerOptionsFor(
          loop[i].answer,
          pool,
          seed: i,
        ).map((o) => o.id).join(','),
        orderedBySeedIndex[i],
        reason: 'ranking or shuffle moved at loop position $i',
      );
      // Selection is order-independent, so it survives the unstable seed.
      expect(
        answerOptionsFor(
          loop[i].answer,
          pool,
          seed: loop[i].optionSeed(i),
        ).map((o) => o.id).toSet(),
        answerOptionsFor(
          loop[i].answer,
          pool,
          seed: i,
        ).map((o) => o.id).toSet(),
        reason: 'the chosen 4 must not depend on the seed, only their order',
      );
    }
  });
}
