/// The practice session as a domain object (Story 1.7): its identity, how it
/// ended, and the event a *completed* one reports.
///
/// Lives in `domain/` because the completed-vs-abandoned decision is a product
/// rule, not a widget concern: the presentation layer decides *when* a session
/// ends, [sessionResultFor] decides whether that ending is worth an event.
/// Keeping the rule here is what lets it be tested without a widget tree — and
/// abandonment is the branch a happy-path widget test never walks.
///
/// Nothing consumes [SessionResultReported] yet. The Progressão module is Epic
/// 2 and will implement [SessionResultReporter] with its ingestion method,
/// overriding the provider in `../data/session_result_reporter.dart`. That
/// override — not a global event bus — is the transport AR-4 asks for.
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'exercise_attempt.dart';

const _uuid = Uuid();

/// Identity and start instant of one practice session.
///
/// [sessionId] is a UUID v4 minted at the opening of the session (AR-11) and
/// never reused: two openings of the practice screen are two sessions, even
/// back to back. Epic 2's ingestion is idempotent *by* this id, so a duplicate
/// would be a silently-dropped session, not a crash — which is why it is
/// generated here, once, rather than derived from anything.
@immutable
class PracticeSession {
  PracticeSession({required this.startedAt, String? sessionId})
    : sessionId = sessionId ?? _uuid.v4();

  /// UUID v4, minted at the opening of the session.
  final String sessionId;

  /// When the session opened, read off the zone-scoped `clock` so tests drive
  /// the session's own timer with the fake clock instead of waiting 12 real
  /// minutes for the end offer.
  final DateTime startedAt;

  /// How long the session has been open at [now].
  Duration elapsedAt(DateTime now) => now.difference(startedAt);

  @override
  String toString() =>
      'PracticeSession(sessionId: $sessionId, startedAt: $startedAt)';
}

/// How a session left the loop.
///
/// [leftEarly] is never stored on the state — a session that is abandoned
/// simply never reaches a terminal phase. It exists so the rule in
/// [isSessionCompleted] can *state* that abandonment is not a completion,
/// rather than leaving it implied by an absent call.
enum SessionEnd {
  /// Answered the last exercise of the sequence.
  reachedEnd,

  /// Took the end offer made at the target time, between two exercises.
  acceptedOffer,

  /// Closed the app or went back mid-session.
  leftEarly,
}

/// The domain event a completed session reports (AR-4).
///
/// One entry per *attempt*, never an aggregate: every score, meter and error
/// profile the Progressão builds is derived from this list on its side of the
/// boundary. `ExerciseAttempt` already carries the four fields the contract
/// names ([ExerciseAttempt.exerciseType], `wasCorrect`, `errorType`,
/// `reactionTimeMs`) — this event adds only the session's identity.
@immutable
class SessionResultReported {
  SessionResultReported({
    required this.sessionId,
    required List<ExerciseAttempt> attempts,
  }) : attempts = List.unmodifiable(attempts);

  /// The [PracticeSession.sessionId] of the session that ended.
  final String sessionId;

  /// One entry per answered exercise, in the order they were answered.
  final List<ExerciseAttempt> attempts;

  @override
  String toString() =>
      'SessionResultReported(sessionId: $sessionId, '
      'attempts: ${attempts.length})';
}

/// The completion rule: reaching the end of the sequence **or** accepting the
/// offer counts as completed, provided at least one exercise was answered.
///
/// The `answered > 0` half is not a formality. An empty loop lands straight on
/// the end-of-loop view, and a learner can walk to the end without answering
/// anything if the sequence is empty — reporting that would credit progress for
/// a session that produced no signal.
bool isSessionCompleted({required SessionEnd end, required int answered}) =>
    end != SessionEnd.leftEarly && answered > 0;

/// The event [session] should report given how it ended, or `null` when the
/// session was abandoned and must report nothing.
///
/// Returning a nullable event rather than throwing is deliberate: "nothing to
/// report" is an ordinary outcome of a practice session, not an error.
SessionResultReported? sessionResultFor({
  required PracticeSession session,
  required SessionEnd end,
  required List<ExerciseAttempt> attempts,
}) => isSessionCompleted(end: end, answered: attempts.length)
    ? SessionResultReported(sessionId: session.sessionId, attempts: attempts)
    : null;

/// Where a completed session's event goes.
///
/// An explicit extension point, injected through
/// `sessionResultReporterProvider`: Epic 2 swaps the logging implementation for
/// the Progressão's `ingest`, and a test swaps it for a recorder. No global
/// event bus (AR-4), so there is exactly one place that can receive this event
/// and it is visible in the provider graph.
abstract interface class SessionResultReporter {
  void report(SessionResultReported event);
}
