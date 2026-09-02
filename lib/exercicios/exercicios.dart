/// Public barrel for the `exercicios` module.
///
/// Re-exports the pure `domain/` (the fixed loop, option generation, the
/// `ExerciseAttempt` value) plus the single route screen from `presentation/`
/// (Rule 1 of the module-boundary gate allows a barrel to re-export
/// `presentation/`). No other module imports `exercicios/presentation|data/`
/// directly. `data/` stays empty in Story 1.4.
library;

export 'domain/exercise_attempt.dart';
export 'domain/interval_options.dart';
export 'domain/interval_practice.dart';
// Only the route screen. The loop notifier / state / phase are presentation
// internals — tests that need them import the file directly.
export 'presentation/interval_exercise_screen.dart' show IntervalExerciseScreen;
