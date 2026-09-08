/// Public barrel for the `exercicios` module.
///
/// Re-exports the pure `domain/` (the type-agnostic question/answer model, the
/// fixed loop, option generation, the practice state, the `ExerciseAttempt`
/// value, the mascot's error explanation, the session and its
/// `SessionResultReported`) plus the single route screen from `presentation/`
/// and the session-result seam from `data/`
/// (Rule 1 of the module-boundary gate allows a barrel to re-export
/// `presentation/` and `data/`). No other module imports
/// `exercicios/presentation|data/` directly.
library;

export 'domain/error_explanation.dart';
export 'domain/exercise_attempt.dart';
export 'domain/exercise_question.dart';
export 'domain/interval_options.dart';
export 'domain/interval_practice.dart';
export 'domain/motif.dart';
export 'domain/practice_state.dart';
export 'domain/session_result.dart';
// The one seam through which a completed session leaves this module: Epic 2's
// Progressão overrides `sessionResultReporterProvider` with its ingestion.
export 'data/session_result_reporter.dart';
// Only the route screen. The loop notifier is a presentation internal — tests
// that need it import the file directly.
export 'presentation/interval_exercise_screen.dart' show IntervalExerciseScreen;
