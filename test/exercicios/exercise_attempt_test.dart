import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_test/flutter_test.dart';

IntervalSpec _spec(String id, int semitones) => IntervalSpec(
  id: id,
  semitones: semitones,
  nameUi: id,
  abbr: id,
  quality: 'x',
);

void main() {
  group('value contract', () {
    test('== / hashCode keyed on all four fields; toString', () {
      const a = ExerciseAttempt(
        exerciseType: ExerciseType.interval,
        wasCorrect: false,
        errorType: ErrorType.majorThird,
        reactionTimeMs: 1200,
      );
      const b = ExerciseAttempt(
        exerciseType: ExerciseType.interval,
        wasCorrect: false,
        errorType: ErrorType.majorThird,
        reactionTimeMs: 1200,
      );
      const differsRt = ExerciseAttempt(
        exerciseType: ExerciseType.interval,
        wasCorrect: false,
        errorType: ErrorType.majorThird,
        reactionTimeMs: 1201,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(differsRt)));
      expect(
        a.toString(),
        'ExerciseAttempt(exerciseType: ExerciseType.interval, '
        'wasCorrect: false, errorType: ErrorType.majorThird, '
        'reactionTimeMs: 1200)',
      );
    });

    test('a correct attempt with a non-null errorType is rejected', () {
      expect(
        () => ExerciseAttempt(
          exerciseType: ExerciseType.interval,
          wasCorrect: true,
          errorType: ErrorType.p5,
          reactionTimeMs: 1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a non-positive reaction time is rejected', () {
      expect(
        () => ExerciseAttempt(
          exerciseType: ExerciseType.interval,
          wasCorrect: true,
          reactionTimeMs: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ExerciseAttempt.forInterval', () {
    final m3 = _spec('M3', 4);

    test('correct answer -> wasCorrect true, errorType null', () {
      final attempt = ExerciseAttempt.forInterval(
        answer: m3,
        picked: m3,
        reactionTimeMs: 900,
      );
      expect(attempt.wasCorrect, isTrue);
      expect(attempt.errorType, isNull);
      expect(attempt.exerciseType, ExerciseType.interval);
      expect(attempt.reactionTimeMs, 900);
    });

    test(
      'wrong answer -> errorType is the ErrorType whose id == picked.id',
      () {
        final attempt = ExerciseAttempt.forInterval(
          answer: m3,
          picked: _spec('P5', 7),
          reactionTimeMs: 1500,
        );
        expect(attempt.wasCorrect, isFalse);
        expect(attempt.errorType, ErrorType.p5);
        expect(attempt.errorType!.id, 'P5');
      },
    );
  });

  test('errorTypeForIntervalId maps every P1..P8 token 1:1', () {
    const ids = [
      'P1', 'm2', 'M2', 'm3', 'M3', 'P4', 'TT', 'P5', 'm6', 'M6', 'm7', 'M7',
      'P8', //
    ];
    for (final id in ids) {
      expect(ExerciseAttempt.errorTypeForIntervalId(id).id, id);
    }
    expect(
      () => ExerciseAttempt.errorTypeForIntervalId('ZZ'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
