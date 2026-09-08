/// The session rule, without a widget tree (Story 1.7).
///
/// The interesting half of this story is what does *not* happen — an abandoned
/// session and a zero-answer session report nothing — and those are the paths a
/// happy-path widget test never walks. Testing the rule as a pure function is
/// what makes them cheap enough to state one by one.
library;

import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_test/flutter_test.dart';

/// RFC 4122 v4: the version nibble is `4` and the variant nibble is 8/9/a/b.
/// Asserting the shape, not just "some string", is the point of AR-11 — Epic 2
/// dedupes ingestion *by* this id.
final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

ExerciseAttempt _attempt({bool correct = true, int ms = 900}) =>
    ExerciseAttempt(
      exerciseType: ExerciseType.interval,
      wasCorrect: correct,
      reactionTimeMs: ms,
      errorType: correct ? null : ErrorType.m3,
    );

PracticeSession _session() => PracticeSession(startedAt: DateTime(2026, 9, 8));

void main() {
  group('PracticeSession', () {
    test('mints a UUID v4 on opening', () {
      expect(_session().sessionId, matches(_uuidV4));
    });

    test('two sessions never share an id', () {
      final ids = List.generate(50, (_) => _session().sessionId).toSet();
      expect(ids, hasLength(50));
    });

    test(
      'an explicit id is kept — the generator is the default, not a rule',
      () {
        // The seam a future story needs to replay or restore a session.
        expect(
          PracticeSession(
            startedAt: DateTime(2026, 9, 8),
            sessionId: 'fixed-id',
          ).sessionId,
          'fixed-id',
        );
      },
    );

    test('elapsed is measured from the opening instant', () {
      final session = PracticeSession(startedAt: DateTime(2026, 9, 8, 10));
      expect(
        session.elapsedAt(DateTime(2026, 9, 8, 10, 12)),
        const Duration(minutes: 12),
      );
    });
  });

  group('isSessionCompleted', () {
    test('reaching the end of the sequence, having answered, completes', () {
      expect(
        isSessionCompleted(end: SessionEnd.reachedEnd, answered: 39),
        isTrue,
      );
    });

    test('accepting the offer, having answered, completes', () {
      expect(
        isSessionCompleted(end: SessionEnd.acceptedOffer, answered: 1),
        isTrue,
      );
    });

    test('leaving early is abandonment, however much was answered', () {
      expect(
        isSessionCompleted(end: SessionEnd.leftEarly, answered: 38),
        isFalse,
      );
    });

    test('zero answers is abandonment, even at the end of the sequence', () {
      // The empty-loop walk: it reaches the end without producing any signal.
      expect(
        isSessionCompleted(end: SessionEnd.reachedEnd, answered: 0),
        isFalse,
      );
      expect(
        isSessionCompleted(end: SessionEnd.acceptedOffer, answered: 0),
        isFalse,
      );
    });
  });

  group('sessionResultFor', () {
    test('a completed session reports its id and every attempt, in order', () {
      final session = _session();
      final attempts = [
        _attempt(ms: 100),
        _attempt(correct: false, ms: 200),
        _attempt(ms: 300),
      ];

      final event = sessionResultFor(
        session: session,
        end: SessionEnd.reachedEnd,
        attempts: attempts,
      )!;

      expect(event.sessionId, session.sessionId);
      expect(event.attempts, attempts);
      expect(
        event.attempts.map((a) => a.reactionTimeMs),
        [100, 200, 300],
        reason:
            'one entry per attempt, in the order they were answered — '
            'aggregation is the Progressão\'s job (AR-4)',
      );
    });

    test('an abandoned session reports nothing', () {
      expect(
        sessionResultFor(
          session: _session(),
          end: SessionEnd.leftEarly,
          attempts: [_attempt(), _attempt()],
        ),
        isNull,
      );
    });

    test('a session with no answers reports nothing', () {
      expect(
        sessionResultFor(
          session: _session(),
          end: SessionEnd.reachedEnd,
          attempts: const [],
        ),
        isNull,
      );
    });

    test('the reported attempts cannot be mutated by the emitter', () {
      final attempts = [_attempt()];
      final event = sessionResultFor(
        session: _session(),
        end: SessionEnd.acceptedOffer,
        attempts: attempts,
      )!;
      expect(() => event.attempts.add(_attempt()), throwsUnsupportedError);
    });
  });
}
