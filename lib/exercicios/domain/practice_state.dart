/// The practice loop's state, as a pure value.
///
/// Lives in `domain/` — not next to the widgets — because the presentation
/// layer is held type-agnostic by `check_module_boundaries` Rule 6, and a state
/// object is where a type leaks back in first. It holds only
/// [ExerciseQuestion] / [AnswerOption], never a catalog spec.
library;

import 'package:catear/curriculo/curriculo.dart';
import 'package:flutter/foundation.dart';

import 'exercise_attempt.dart';
import 'exercise_question.dart';
import 'session_result.dart';

/// Where the loop is.
///
/// The first three are about the current exercise; [offeringEnd] and [finished]
/// are about the session around it. [offeringEnd] sits *between* two exercises
/// — the previous one is answered and the next one has not mounted yet — which
/// is the only place UX-DR12's offer is allowed to appear: never over a card in
/// progress, never over playing audio.
enum AnswerPhase { answering, correct, incorrect, offeringEnd, finished }

const Object _keep = Object();

/// Immutable snapshot of the fixed practice loop.
@immutable
class PracticeState {
  PracticeState({
    required this.session,
    required List<ExerciseQuestion> loop,
    required Map<ExerciseType, List<AnswerOption>> pool,
    required this.index,
    required List<AnswerOption> options,
    required this.phase,
    required List<ExerciseAttempt> attempts,
    this.picked,
    this.endOffered = false,
    this.ending,
  }) : loop = List.unmodifiable(loop),
       // Deep: `Map.unmodifiable` freezes the map, not the lists inside it,
       // and `pool[type]` is handed straight to callers.
       pool = Map.unmodifiable({
         for (final entry in pool.entries)
           entry.key: List<AnswerOption>.unmodifiable(entry.value),
       }),
       options = List.unmodifiable(options),
       attempts = List.unmodifiable(attempts);

  /// The session this loop belongs to: its `sessionId` (UUID v4) and the
  /// instant it opened. Minted once per opening of the screen — never derived
  /// from the loop, and never reused across two openings.
  final PracticeSession session;

  /// Every question of the loop, in stage order (39 in v1: 23 intervals,
  /// 8 chords, 8 scales).
  final List<ExerciseQuestion> loop;

  /// The distractor pool, one list per type (13 / 4 / 4 in v1). Keyed by type
  /// so a question's alternatives can never be drawn from another catalog.
  final Map<ExerciseType, List<AnswerOption>> pool;

  /// Position in [loop].
  final int index;

  /// The 4 (or fewer) options for the current exercise, in display order.
  final List<AnswerOption> options;

  final AnswerPhase phase;

  /// Attempts recorded so far, one per answered exercise. In-memory only —
  /// they leave this object as the `attempts` of a `SessionResultReported`
  /// when the session completes, and are dropped on abandonment.
  final List<ExerciseAttempt> attempts;

  /// The option the user tapped, once answered.
  final AnswerOption? picked;

  /// Whether the end offer has already been made. Once made and declined it
  /// does not come back — an offer that reappeared after every exercise would
  /// be the nagging UX-DR12 rules out.
  final bool endOffered;

  /// How the session ended, once it has. `null` while it is running, and
  /// `null` forever for an abandoned session — abandonment is the absence of
  /// an ending, not one of its kinds.
  final SessionEnd? ending;

  ExerciseQuestion get current => loop[index];
  AnswerOption get answer => current.answer;

  PracticeState copyWith({
    int? index,
    List<AnswerOption>? options,
    AnswerPhase? phase,
    List<ExerciseAttempt>? attempts,
    Object? picked = _keep,
    bool? endOffered,
    SessionEnd? ending,
  }) => PracticeState(
    session: session,
    loop: loop,
    pool: pool,
    index: index ?? this.index,
    options: options ?? this.options,
    phase: phase ?? this.phase,
    attempts: attempts ?? this.attempts,
    picked: identical(picked, _keep) ? this.picked : picked as AnswerOption?,
    endOffered: endOffered ?? this.endOffered,
    // No sentinel: an ending is set once and never cleared, so there is
    // nothing to express by passing `null` explicitly.
    ending: ending ?? this.ending,
  );
}
