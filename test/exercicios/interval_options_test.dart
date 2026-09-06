import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<AnswerOption> pool; // the real 13
  late AnswerOption Function(String id) spec;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final curriculum = await container.read(curriculoRepositoryProvider).load();
    pool = practicePool(curriculum);
    spec = (id) => pool.firstWhere((s) => s.id == id);
  });

  test('returns 4 distinct options and always includes the answer', () {
    final answer = spec('M3');
    final options = answerOptionsFor(answer, pool, seed: 42);
    expect(options.length, 4);
    expect(options.map((o) => o.id).toSet().length, 4);
    expect(options.map((o) => o.id), contains('M3'));
  });

  test('deterministic for a given seed, different across seeds', () {
    final answer = spec('P5');
    final a = answerOptionsFor(answer, pool, seed: 7);
    final b = answerOptionsFor(answer, pool, seed: 7);
    expect(a.map((o) => o.id).toList(), b.map((o) => o.id).toList());

    final orders = {
      for (final s in [1, 2, 3, 4, 5])
        answerOptionsFor(answer, pool, seed: s).map((o) => o.id).join(','),
    };
    expect(orders.length, greaterThan(1), reason: 'seed changes the order');
  });

  test('the same 4 specs regardless of seed (only order changes)', () {
    final answer = spec('M6');
    final s1 = answerOptionsFor(answer, pool, seed: 1).map((o) => o.id).toSet();
    final s2 = answerOptionsFor(
      answer,
      pool,
      seed: 99,
    ).map((o) => o.id).toSet();
    expect(s1, s2);
  });

  test('distractors are the 3 nearest by semitone distance', () {
    final answer = spec('M3'); // 4 semitones
    final options = answerOptionsFor(answer, pool, seed: 3);
    final distractors = options.where((o) => o.id != 'M3').toList();

    // The reference ordering is computed from the catalog's own semitone
    // values, NOT from `distanceTo` — otherwise this test would compare the
    // implementation against itself and any ranking bug would pass.
    const semitones = {
      'P1': 0,
      'm2': 1,
      'M2': 2,
      'm3': 3,
      'M3': 4,
      'P4': 5,
      'TT': 6,
      'P5': 7,
      'm6': 8,
      'M6': 9,
      'm7': 10,
      'M7': 11,
      'P8': 12,
    };
    final expectedNearest =
        (pool.where((s) => s.id != 'M3').toList()..sort((a, b) {
              final da = (semitones[a.id]! - semitones['M3']!).abs();
              final db = (semitones[b.id]! - semitones['M3']!).abs();
              return da != db ? da.compareTo(db) : a.id.compareTo(b.id);
            }))
            .take(3)
            .map((s) => s.id)
            .toSet();
    expect(distractors.map((o) => o.id).toSet(), expectedNearest);
    // Every distractor is within 2 semitones of the answer.
    expect(distractors.every((o) => answer.distanceTo(o) <= 2), isTrue);
  });

  test('an interval option distance is exactly |delta semitones|', () {
    // The generic metric must reproduce Story 1.4's ranking, not approximate
    // it: a one-element profile makes `distanceTo` the old subtraction.
    expect(spec('P1').distanceTo(spec('P8')), 12);
    expect(spec('M3').distanceTo(spec('m3')), 1);
    expect(spec('TT').distanceTo(spec('TT')), 0);
  });

  test('the same machinery ranks chord and scale options', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final curriculum = await container.read(curriculoRepositoryProvider).load();

    final chordPool = practicePool(
      curriculum,
      types: const {ExerciseType.chord},
    );
    final major = chordPool.firstWhere((o) => o.id == 'major');
    final chordOptions = answerOptionsFor(major, chordPool, seed: 11);
    expect(chordOptions.length, 4);
    expect(chordOptions.map((o) => o.id), contains('major'));

    final scalePool = practicePool(
      curriculum,
      types: const {ExerciseType.scale},
    );
    final scaleMajor = scalePool.firstWhere((o) => o.id == 'major');
    final mixolydian = scalePool.firstWhere((o) => o.id == 'mixolydian');
    final naturalMinor = scalePool.firstWhere((o) => o.id == 'natural_minor');
    // Mixolydian is one altered degree away from major; natural minor is three.
    expect(
      scaleMajor.distanceTo(mixolydian),
      lessThan(scaleMajor.distanceTo(naturalMinor)),
    );
    expect(answerOptionsFor(scaleMajor, scalePool, seed: 11).length, 4);
  });

  test('pool smaller than 4 returns what there is, still includes answer', () {
    final answer = spec('P1');
    final small = [answer, spec('M2')];
    final options = answerOptionsFor(answer, small, seed: 5);
    expect(options.length, 2);
    expect(options.map((o) => o.id), containsAll(<String>['P1', 'M2']));

    final justAnswer = answerOptionsFor(answer, [answer], seed: 5);
    expect(justAnswer.map((o) => o.id), ['P1']);
  });
}
