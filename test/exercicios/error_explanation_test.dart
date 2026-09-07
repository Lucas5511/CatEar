import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_test/flutter_test.dart';

AnswerOption _option(String id, String nameUi, List<int> profile) =>
    AnswerOption(id: id, nameUi: nameUi, semitoneProfile: profile);

final _majorThird = _option('M3', 'terça maior', const [4]);
final _minorThird = _option('m3', 'terça menor', const [3]);
final _majorTriad = _option('major', 'tríade maior', const [4, 7]);
final _dimTriad = _option('diminished', 'tríade diminuta', const [3, 6]);
final _majorScale = _option('major', 'escala maior', const [
  2,
  4,
  5,
  7,
  9,
  11,
  12,
]);
final _mixolydian = _option('mixolydian', 'escala mixolídia', const [
  2,
  4,
  5,
  7,
  9,
  10,
  12,
]);
final _dorian = _option('dorian', 'escala dórica', const [
  2,
  3,
  5,
  7,
  9,
  10,
  12,
]);
final _naturalMinor = _option('natural_minor', 'escala menor natural', const [
  2,
  3,
  5,
  7,
  8,
  10,
  12,
]);

void main() {
  group('base layer — names the pair', () {
    test('an interval confusion names both nameUi', () {
      final text = errorExplanation(
        answer: _majorThird,
        picked: _minorThird,
        errorType: ErrorType.m3,
      );
      expect(text, contains('terça maior'));
      expect(text, contains('terça menor'));
      expect(text, contains('confundiu'));
    });

    test('a chord confusion uses the same template', () {
      final text = errorExplanation(
        answer: _majorTriad,
        picked: _dimTriad,
        errorType: ErrorType.diminished,
      );
      expect(text, contains('tríade maior'));
      expect(text, contains('tríade diminuta'));
    });
  });

  group('specific layer — the taxonomy adds something', () {
    test('a one-degree scale error names the degree, not the modes', () {
      final text = errorExplanation(
        answer: _majorScale,
        picked: _mixolydian,
        errorType: ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.scale,
          answer: _majorScale,
          picked: _mixolydian,
        ),
      );
      expect(text, contains('7ª'));
      expect(text, contains('escala maior'));
      // Names the degree instead of merely stating the two modes were swapped.
      expect(text, isNot(contains('confundiu')));
    });

    test('every altered-degree ErrorType has a phrase of its own', () {
      for (final entry in alteredDegreeNames.entries) {
        final text = errorExplanation(
          answer: _majorScale,
          picked: _mixolydian,
          errorType: entry.key,
        );
        expect(
          text,
          contains(entry.value),
          reason: '${entry.key} must name ${entry.value}',
        );
      }
    });

    test('alteredDegreeNames is the exact inverse of scaleErrorTypeByDegree', () {
      // Not `hasLength(3)`: that catches a removal and misses an addition, and
      // a degree added to the taxonomy with no phrase here would fall through
      // to the base template — the modes named, the lesson lost.
      expect(
        alteredDegreeNames.keys.toSet(),
        scaleErrorTypeByDegree.values.toSet(),
      );
    });

    test('every degree the taxonomy can resolve reaches its own phrase', () {
      // Through the real path: the mode pair goes to `errorTypeFor`, and its
      // answer goes to `errorExplanation`. No injected [ErrorType] anywhere,
      // so a break anywhere in that chain shows up here. One catalog pair per
      // degree — the three the four v1 modes can form.
      final pairs = <int, (AnswerOption, AnswerOption)>{
        3: (_mixolydian, _dorian),
        6: (_naturalMinor, _dorian),
        7: (_majorScale, _mixolydian),
      };
      for (final entry in pairs.entries) {
        final degree = entry.key;
        final (answer, picked) = entry.value;
        final resolved = ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.scale,
          answer: answer,
          picked: picked,
        );
        expect(
          resolved,
          scaleErrorTypeByDegree[degree],
          reason: 'degree $degree: ${answer.id} vs ${picked.id}',
        );
        expect(
          errorExplanation(answer: answer, picked: picked, errorType: resolved),
          contains(alteredDegreeNames[resolved]!),
          reason: 'degree $degree must be named out loud',
        );
      }
      expect(pairs.keys.toSet(), scaleErrorTypeByDegree.keys.toSet());
    });

    test('far-miss names the right answer and invites another listen', () {
      final text = errorExplanation(
        answer: _majorScale,
        picked: _naturalMinor,
        errorType: ExerciseAttempt.errorTypeFor(
          exerciseType: ExerciseType.scale,
          answer: _majorScale,
          picked: _naturalMinor,
        ),
      );
      expect(text, contains('escala maior'));
      expect(text, contains('escala menor natural'));
      expect(text, contains('Ouça de novo'));
    });
  });

  group('never bare, never throwing', () {
    test('every ErrorType produces a non-empty sentence naming the answer', () {
      for (final errorType in ErrorType.values) {
        final text = errorExplanation(
          answer: _majorThird,
          picked: _minorThird,
          errorType: errorType,
        );
        expect(text, isNotEmpty, reason: '$errorType');
        expect(text, contains('terça maior'), reason: '$errorType');
        expect(
          text.toLowerCase(),
          isNot(contains('errado')),
          reason: 'never a bare verdict (FR-4)',
        );
      }
    });

    test('a missing picked / errorType still names the answer', () {
      for (final text in [
        errorExplanation(answer: _majorThird),
        errorExplanation(answer: _majorThird, picked: _minorThird),
        errorExplanation(answer: _majorThird, errorType: ErrorType.farMiss),
      ]) {
        expect(text, contains('terça maior'));
      }
    });
  });
}
