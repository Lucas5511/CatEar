/// Public barrel for the `exercicios` module.
///
/// Re-exports the pure `domain/` (the type-agnostic question/answer model, the
/// fixed loop, option generation, the anti-decoreba variation rules, the
/// practice state, the `ExerciseAttempt` value, the mascot's error explanation,
/// the session and its `SessionResultReported`) plus, from `presentation/`,
/// the route screen and the exercise card that is this module's shared UI
/// contract, and the session-result seam from `data/`
/// (Rule 1 of the module-boundary gate allows a barrel to re-export
/// `presentation/` and `data/`). No other module imports
/// `exercicios/presentation|data/` directly.
library;

export 'domain/error_explanation.dart';
export 'domain/exercise_attempt.dart';
export 'domain/exercise_question.dart';
export 'domain/exercise_variation.dart';
export 'domain/interval_options.dart';
export 'domain/interval_practice.dart';
export 'domain/motif.dart';
export 'domain/practice_state.dart';
export 'domain/session_result.dart';
// The one seam through which a completed session leaves this module: Epic 2's
// Progressão overrides `sessionResultReporterProvider` with its ingestion.
export 'data/session_result_reporter.dart';
// The route screen, and the exercise card as a shared UI contract (AD-1):
// Story 1.9's levelling module renders the same card with its own notifier,
// driving it through `onAnswer` / `onAdvance`. The session notifier itself
// stays a presentation internal — tests that need it import the file
// directly; only the type-selection seam the E2E narrows the loop with is
// re-exported.
export 'presentation/exercise_card_flow.dart' show ExerciseCardFlow;
export 'presentation/practice_controller.dart'
    show practiceExerciseTypesProvider;
export 'presentation/practice_screen.dart' show PracticeScreen;
