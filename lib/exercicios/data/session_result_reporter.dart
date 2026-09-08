/// The wiring for [SessionResultReporter] (Story 1.7).
///
/// In `data/` for the same reason `audioServiceProvider` is: `domain/` owns the
/// interface, `data/` owns the implementation and the provider that hands it
/// out. Reached from outside the module only through the barrel.
///
/// The default implementation logs, because the consumer does not exist yet —
/// the Progressão and its ingestion are Epic 2 (AR-4). When it lands, it
/// overrides this provider; nothing in `presentation/` changes.
library;

import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/session_result.dart';

part 'session_result_reporter.g.dart';

/// Logs a completed session, one line for the session and one per attempt.
///
/// Named fields rather than a bare `toString()` of the whole event: the
/// per-attempt log Story 1.4 left behind was a stringly-typed dump, and the
/// deferred item asked 1.7 to revisit it. The answer 1.7 gives is that the
/// structure belongs in the *event* — a typed object handed to a typed
/// interface — and the log is the debug shadow of it, not the contract.
class LoggingSessionResultReporter implements SessionResultReporter {
  const LoggingSessionResultReporter();

  static const _logName = 'catear.exercicios.session';

  @override
  void report(SessionResultReported event) {
    developer.log(
      'sessionId=${event.sessionId} attempts=${event.attempts.length} '
      'correct=${event.attempts.where((a) => a.wasCorrect).length}',
      name: _logName,
    );
    for (final attempt in event.attempts) {
      developer.log(
        'sessionId=${event.sessionId} '
        'exerciseType=${attempt.exerciseType.name} '
        'wasCorrect=${attempt.wasCorrect} '
        'errorType=${attempt.errorType?.id} '
        'reactionTimeMs=${attempt.reactionTimeMs}',
        name: _logName,
      );
    }
  }
}

/// The single receiver of [SessionResultReported]. Override it to consume the
/// event (Epic 2) or to record it (tests).
@riverpod
SessionResultReporter sessionResultReporter(Ref ref) =>
    const LoggingSessionResultReporter();
