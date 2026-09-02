import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<IntervalSpec> pool; // the real 13
  late IntervalSpec Function(String id) spec;

  setUpAll(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final curriculum = await container.read(curriculoRepositoryProvider).load();
    pool = intervalPool(curriculum);
    spec = (id) => pool.firstWhere((s) => s.id == id);
  });

  test('returns 4 distinct options and always includes the answer', () {
    final answer = spec('M3');
    final options = intervalOptionsFor(answer, pool, seed: 42);
    expect(options.length, 4);
    expect(options.map((o) => o.id).toSet().length, 4);
    expect(options.map((o) => o.id), contains('M3'));
  });

  test('deterministic for a given seed, different across seeds', () {
    final answer = spec('P5');
    final a = intervalOptionsFor(answer, pool, seed: 7);
    final b = intervalOptionsFor(answer, pool, seed: 7);
    expect(a.map((o) => o.id).toList(), b.map((o) => o.id).toList());

    final orders = {
      for (final s in [1, 2, 3, 4, 5])
        intervalOptionsFor(answer, pool, seed: s).map((o) => o.id).join(','),
    };
    expect(orders.length, greaterThan(1), reason: 'seed changes the order');
  });

  test('the same 4 specs regardless of seed (only order changes)', () {
    final answer = spec('M6');
    final s1 = intervalOptionsFor(
      answer,
      pool,
      seed: 1,
    ).map((o) => o.id).toSet();
    final s2 = intervalOptionsFor(
      answer,
      pool,
      seed: 99,
    ).map((o) => o.id).toSet();
    expect(s1, s2);
  });

  test('distractors are the 3 nearest by semitone distance', () {
    final answer = spec('M3'); // 4 semitones
    final options = intervalOptionsFor(answer, pool, seed: 3);
    final distractors = options.where((o) => o.id != 'M3').toList();

    final expectedNearest =
        (pool.where((s) => s.id != 'M3').toList()..sort((a, b) {
              final da = (a.semitones - answer.semitones).abs();
              final db = (b.semitones - answer.semitones).abs();
              return da != db ? da.compareTo(db) : a.id.compareTo(b.id);
            }))
            .take(3)
            .map((s) => s.id)
            .toSet();
    expect(distractors.map((o) => o.id).toSet(), expectedNearest);
    // Every distractor is within 2 semitones of the answer.
    expect(
      distractors.every((o) => (o.semitones - answer.semitones).abs() <= 2),
      isTrue,
    );
  });

  test('pool smaller than 4 returns what there is, still includes answer', () {
    final answer = spec('P1');
    final small = [answer, spec('M2')];
    final options = intervalOptionsFor(answer, small, seed: 5);
    expect(options.length, 2);
    expect(options.map((o) => o.id), containsAll(<String>['P1', 'M2']));

    final justAnswer = intervalOptionsFor(answer, [answer], seed: 5);
    expect(justAnswer.map((o) => o.id), ['P1']);
  });
}
