import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixed loop (`intervalLoop`) and distractor pool (`intervalPool`) against
/// the real `catalog_v1.json`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Curriculum> loadReal() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(curriculoRepositoryProvider).load();
  }

  test('loop is every IntervalExercise in stage order, nothing else', () async {
    final loop = intervalLoop(await loadReal());

    // 23 interval exercises across the 7 interval stages of v1.
    expect(loop.length, 23);
    expect(loop.every((e) => e.type == ExerciseType.interval), isTrue);
    expect(loop.first.interval.id, 'P1');
    expect(loop.first.direction, Direction.asc);
    expect(loop.last.interval.id, 'TT');
    expect(loop.last.direction, Direction.desc);
  });

  test('loop excludes chord / scale / resolution exercises', () async {
    final curriculum = await loadReal();
    final loopRefs = intervalLoop(curriculum).toSet();
    final allInterval = curriculum.stages
        .expand((s) => s.exercises)
        .whereType<IntervalExercise>()
        .toSet();
    expect(loopRefs, allInterval);
    expect(
      curriculum.stages
          .expand((s) => s.exercises)
          .any((e) => e is! IntervalExercise),
      isTrue,
      reason: 'the catalog does contain non-interval exercises',
    );
  });

  test('loop honours stage.order even if stages come pre-sorted', () async {
    final loop = intervalLoop(await loadReal());
    // P1/P8/P5 (order 1) precede the thirds (order 3) precede the tritone (10).
    final ids = loop.map((e) => e.interval.id).toList();
    expect(ids.indexOf('P1') < ids.indexOf('M3'), isTrue);
    expect(ids.indexOf('M3') < ids.indexOf('TT'), isTrue);
  });

  test('pool is the 13 distinct IntervalSpecs, first-seen order', () async {
    final pool = intervalPool(await loadReal());
    expect(pool.length, 13);
    expect(pool.map((s) => s.id).toSet(), {
      'P1', 'm2', 'M2', 'm3', 'M3', 'P4', 'TT', 'P5', 'm6', 'M6', 'm7', 'M7',
      'P8', //
    });
    expect(pool.first.id, 'P1', reason: 'first exercise is P1');
    // No duplicates.
    expect(pool.map((s) => s.id).toList().toSet().length, pool.length);
  });
}
