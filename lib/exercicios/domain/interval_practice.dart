/// Pure functions that turn the curriculum catalog into the fixed interval
/// practice loop of Story 1.4.
///
/// No session sizing (1.7), no anti-decoreba variation (1.8), no randomness:
/// every `IntervalExercise` of the catalog, in `stage.order`, once.
library;

import 'package:catear/curriculo/curriculo.dart';

/// The fixed loop: every [IntervalExercise] flattened in ascending `stage.order`
/// (the JSON array order is not canonical). `chord` / `scale` / `resolution`
/// exercises are excluded.
List<IntervalExercise> intervalLoop(Curriculum curriculum) {
  final stages = [...curriculum.stages]
    ..sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.stageId.compareTo(b.stageId);
    });
  return [
    for (final stage in stages)
      for (final exercise in stage.exercises)
        if (exercise is IntervalExercise) exercise,
  ];
}

/// The distinct [IntervalSpec]s that appear in the interval loop, in first-seen
/// order. This is the distractor pool for `intervalOptionsFor` (13 in v1).
List<IntervalSpec> intervalPool(Curriculum curriculum) {
  final seen = <String>{};
  final pool = <IntervalSpec>[];
  for (final exercise in intervalLoop(curriculum)) {
    if (seen.add(exercise.interval.id)) pool.add(exercise.interval);
  }
  return pool;
}
