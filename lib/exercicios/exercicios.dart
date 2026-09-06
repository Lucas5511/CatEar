/// Public barrel for the `exercicios` module.
///
/// Re-exports the pure `domain/` (the type-agnostic question/answer model, the
/// fixed loop, option generation, the practice state, the `ExerciseAttempt`
/// value) plus the single route screen from `presentation/`
/// (Rule 1 of the module-boundary gate allows a barrel to re-export
/// `presentation/`). No other module imports `exercicios/presentation|data/`
/// directly. `data/` stays empty in Story 1.4.
library;

export 'domain/exercise_attempt.dart';
export 'domain/exercise_question.dart';
export 'domain/interval_options.dart';
export 'domain/interval_practice.dart';
export 'domain/motif.dart';
export 'domain/practice_state.dart';
// Only the route screen. The loop notifier is a presentation internal — tests
// that need it import the file directly.
export 'presentation/interval_exercise_screen.dart' show IntervalExerciseScreen;
