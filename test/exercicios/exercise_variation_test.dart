import 'dart:io';

import 'package:catear/audio/audio.dart';
import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Story 1.8 — anti-decoreba variation, as pure functions.
///
/// Everything here runs without a database: the history is an argument, so the
/// selection rule (window, least-recently-used, exhausted pool) is testable
/// without a single `await` on Drift. `test/progressao/variant_history_test.dart`
/// covers the storage half.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Curriculum> loadReal() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(curriculoRepositoryProvider).load();
  }

  /// The catalog exercises in the same order `practiceLoop` walks them.
  List<Exercise> orderedExercises(Curriculum curriculum) {
    final stages = [...curriculum.stages]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.stageId.compareTo(b.stageId);
      });
    return [
      for (final stage in stages)
        for (final e in stage.exercises)
          if (!e.requiresVoice) e,
    ];
  }

  /// The history a completed loop leaves behind, newest first.
  List<VariantUse> historyFrom(
    List<ExerciseQuestion> loop, {
    int startSequence = 1,
  }) {
    var sequence = startSequence;
    final uses = <VariantUse>[];
    for (final question in loop) {
      final variant = question.variant;
      if (variant == null) continue;
      uses.add(
        VariantUse(
          relationKey: variant.relationKey,
          rootToken: variant.rootToken,
          sequence: sequence++,
        ),
      );
    }
    return uses.reversed.toList();
  }

  ExerciseVariant variant(String relationKey, String rootToken) =>
      ExerciseVariant(relationKey: relationKey, rootToken: rootToken);

  List<VariantUse> window(List<(String, String)> newestFirst) => [
    for (var i = 0; i < newestFirst.length; i++)
      VariantUse(
        relationKey: newestFirst[i].$1,
        rootToken: newestFirst[i].$2,
        sequence: newestFirst.length - i,
      ),
  ];

  group('the token -> semitone map', () {
    test('holds the 14 isolated notes, and only those', () {
      expect(noteSemitonesByToken.length, 14);
      expect(noteTokensByPitch.length, 14);
      // The triad blocks have their root baked in: they are files, not notes,
      // and asking for their pitch must answer "there isn't one".
      for (final block in ['sax_maj_c4', 'sax_min_d4', 'sax_aug_c4']) {
        expect(noteSemitonesByToken[block], isNull, reason: block);
        expect(transposedNoteToken(block, 2), isNull, reason: block);
      }
    });

    test('records the hole in the inventory rather than papering over it', () {
      // C4-C5 chromatic is 0..12; D5 is 14. 13 (Db5) does not exist, and the
      // whole variation ceiling follows from that one gap.
      expect(noteTokenAtSemitone(12), 'sax_c5');
      expect(noteTokenAtSemitone(13), isNull, reason: 'Db5 is not in the set');
      expect(noteTokenAtSemitone(14), 'sax_d5');
      expect(transposedNoteToken('sax_c5', 1), isNull);
      expect(transposedNoteToken('sax_c5', 2), 'sax_d5');
      expect(transposedNoteToken('sax_c4', 4), 'sax_e4');
      expect(transposedNoteToken('sax_e4', -4), 'sax_c4');
      expect(
        transposedNoteToken('sax_c4', 15),
        isNull,
        reason: 'above the top',
      );
      expect(transposedNoteToken('sax_c4', -1), isNull, reason: 'below C4');
    });

    test('is ordered by pitch, not by map literal order', () {
      final semitones = [
        for (final token in noteTokensByPitch) noteSemitonesByToken[token]!,
      ];
      expect(
        semitones,
        orderedEquals([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14]),
      );
    });

    test('every token it names is a file the bundle ships', () {
      final files = Directory('assets/audio')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      for (final token in noteSemitonesByToken.keys) {
        expect(files, contains('$token.wav'), reason: token);
      }
    });
  });

  group('the pool of roots', () {
    test('matches the ceiling measured against the sample set', () async {
      // The table in the spec's Design Notes, as an assertion. It is derived
      // from `intervalCatalog[].semitones` and the inventory, so it moves only
      // if one of those does — which is exactly when it should fail.
      const expected = <String, int>{
        'P1': 14, 'm2': 12, 'M2': 12, 'm3': 11, 'M3': 10, 'P4': 9, 'TT': 8,
        'P5': 7, 'm6': 6, 'M6': 5, 'm7': 4, 'M7': 3, 'P8': 2, //
      };
      const expectedScales = <String, int>{
        'major': 1, // only C4: D major would need Db5
        'natural_minor': 2, 'dorian': 2, 'mixolydian': 2, //
      };

      for (final exercise in orderedExercises(await loadReal())) {
        final pool = variantsFor(exercise);
        switch (exercise) {
          case IntervalExercise():
            expect(
              pool.length,
              expected[exercise.interval.id],
              reason: '${exercise.interval.id} ${exercise.direction.name}',
            );
          case ScaleExercise():
            expect(
              pool.length,
              expectedScales[exercise.scale.id],
              reason: '${exercise.scale.id} ${exercise.direction.name}',
            );
          case ChordExercise():
            expect(pool, isEmpty, reason: 'a chord does not vary');
          case ResolutionExercise():
            expect(pool, isEmpty);
        }
      }
    });

    test('a root that would leave the inventory never enters it', () async {
      // The "impossible root" row of the matrix, checked exhaustively: every
      // root of every pool must resolve every note of its relation.
      final files = Directory('assets/audio')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();

      for (final exercise in orderedExercises(await loadReal())) {
        for (final root in variantsFor(exercise)) {
          for (final ref in refsForVariant(exercise, root)) {
            expect(
              files,
              contains('$ref.wav'),
              reason: '${root.relationKey} from ${root.rootToken}',
            );
          }
        }
      }
    });

    test('the lowest root reproduces the catalog refs exactly', () async {
      // Why the pool is pitch-ordered: an install with no history plays what
      // the catalog writes, so nothing about Story 1.8 changes what a first
      // session sounds like.
      for (final exercise in orderedExercises(await loadReal())) {
        final pool = variantsFor(exercise);
        if (pool.isEmpty) continue;
        expect(
          refsForVariant(exercise, pool.first),
          exercise.audioSampleRefs,
          reason: pool.first.relationKey,
        );
      }
    });

    test('descending relations are the ascending ones, reversed', () async {
      final exercises = orderedExercises(await loadReal());
      final ascM3 = exercises.whereType<IntervalExercise>().firstWhere(
        (e) => e.interval.id == 'M3' && e.direction == Direction.asc,
      );
      final descM3 = exercises.whereType<IntervalExercise>().firstWhere(
        (e) => e.interval.id == 'M3' && e.direction == Direction.desc,
      );
      final root = variant('interval:M3:desc', 'sax_d4');
      expect(refsForVariant(descM3, root), ['sax_gb4', 'sax_d4']);
      expect(refsForVariant(ascM3, variant('interval:M3:asc', 'sax_d4')), [
        'sax_d4',
        'sax_gb4',
      ]);
      // …and the two get separate rotations: the key names the direction.
      expect(
        variantsFor(ascM3).first.relationKey,
        isNot(variantsFor(descM3).first.relationKey),
      );
    });

    test(
      'a scale is built from its catalog steps, not from a mode name',
      () async {
        final dorianAsc = orderedExercises(await loadReal())
            .whereType<ScaleExercise>()
            .firstWhere(
              (e) => e.scale.id == 'dorian' && e.direction == Direction.asc,
            );
        // D dorian, straight off `steps: [2, 1, 2, 2, 2, 1, 2]`.
        expect(
          refsForVariant(dorianAsc, variant('scale:dorian:asc', 'sax_d4')),
          [
            'sax_d4', 'sax_e4', 'sax_f4', 'sax_g4', //
            'sax_a4', 'sax_b4', 'sax_c5', 'sax_d5',
          ],
        );
      },
    );
  });

  group('choosing a variation', () {
    const key = 'interval:M3:asc';
    final pool = [
      variant(key, 'sax_c4'),
      variant(key, 'sax_db4'),
      variant(key, 'sax_d4'),
    ];

    test('an empty history takes the lowest root', () {
      expect(chooseVariant(pool, const []), pool.first);
    });

    test('a root inside the window is skipped', () {
      expect(chooseVariant(pool, window([(key, 'sax_c4')])), pool[1]);
      expect(
        chooseVariant(pool, window([(key, 'sax_db4'), (key, 'sax_c4')])),
        pool[2],
      );
    });

    test('another relation in the window does not consume this pool', () {
      // The window is global (it counts exercises), but the rule is per
      // relation: a root "used" by a different relation is still fresh here.
      expect(
        chooseVariant(pool, window([('interval:P5:asc', 'sax_c4')])),
        pool.first,
      );
    });

    test('an exhausted pool falls back to the least recently used', () {
      // Newest first: d4 played last, then db4, then c4 — so c4 is the LRU.
      final exhausted = window([
        (key, 'sax_d4'),
        (key, 'sax_db4'),
        (key, 'sax_c4'),
      ]);
      final chosen = chooseVariant(pool, exhausted);
      expect(chosen, pool.first, reason: 'sax_c4 is the least recent');
      expect(
        chosen.rootToken,
        isNot('sax_d4'),
        reason: 'never the one that just played',
      );
    });

    test('an exhausted pool never locks up and never repeats the last', () {
      // Walk it round several times: it must keep answering, and never twice
      // in a row while the pool has more than one root.
      var history = window([
        (key, 'sax_d4'),
        (key, 'sax_db4'),
        (key, 'sax_c4'),
      ]);
      var sequence = history.first.sequence;
      String? previous;
      for (var i = 0; i < 12; i++) {
        final chosen = chooseVariant(pool, history);
        expect(chosen.rootToken, isNot(previous), reason: 'round $i');
        previous = chosen.rootToken;
        history = [
          VariantUse(
            relationKey: key,
            rootToken: chosen.rootToken,
            sequence: ++sequence,
          ),
          ...history,
        ];
      }
    });

    test('a pool of one repeats, without failing', () {
      // The major scale: only C4 resolves. The ceiling is given, not a fault.
      final single = [variant('scale:major:asc', 'sax_c4')];
      var history = <VariantUse>[];
      for (var i = 0; i < 3; i++) {
        final chosen = chooseVariant(single, history);
        expect(chosen, single.single);
        history = [
          VariantUse(
            relationKey: chosen.relationKey,
            rootToken: chosen.rootToken,
            sequence: i + 1,
          ),
          ...history,
        ];
      }
    });

    test('an empty pool is a caller error, not a silent null', () {
      expect(() => chooseVariant(const [], const []), throwsArgumentError);
    });
  });

  group('the loop, session after session', () {
    test('with no history it plays exactly what the catalog writes', () async {
      final curriculum = await loadReal();
      final loop = practiceLoop(curriculum);
      final exercises = orderedExercises(curriculum);
      expect(loop.length, exercises.length);
      for (var i = 0; i < loop.length; i++) {
        expect(
          loop[i].audioSampleRefs,
          exercises[i].audioSampleRefs,
          reason: 'position $i',
        );
      }
    });

    test(
      'two sessions running never repeat a variation with room to move',
      () async {
        final curriculum = await loadReal();
        final first = practiceLoop(curriculum);
        final second = practiceLoop(curriculum, history: historyFrom(first));
        final exercises = orderedExercises(curriculum);

        expect(second.length, first.length);
        var moved = 0;
        for (var i = 0; i < first.length; i++) {
          final pool = variantsFor(exercises[i]);
          if (pool.length > 1) {
            expect(
              second[i].variant,
              isNot(first[i].variant),
              reason: 'position $i (${first[i].answer.id}) repeated its root',
            );
            expect(
              second[i].audioSampleRefs,
              isNot(first[i].audioSampleRefs),
              reason: 'position $i sounds identical to the previous session',
            );
            moved++;
          } else {
            // A chord (no pool) or the major scale (one root): unchanged, by
            // design, and that is not a failure.
            expect(second[i].audioSampleRefs, first[i].audioSampleRefs);
          }
        }
        expect(moved, greaterThan(25), reason: 'most of the loop must vary');
      },
    );

    test(
      'the roots actually visited grow with the pool, session after session',
      () async {
        // The test the first implementation did not have, and the reason it
        // shipped a two-root alternation against pools of up to 14: every
        // other multi-session test either stops at two sessions or only checks
        // that the refs name real files, and a c4/db4 ping-pong satisfies both
        // forever.
        //
        // The history is fed back exactly the way the app feeds it — a window
        // of `variantWindow` rows for what may not play, and the latest use of
        // every (relation, root) pair for how the rest are ordered.
        final curriculum = await loadReal();
        final exercises = orderedExercises(curriculum);
        final log = <VariantUse>[]; // newest first, whole retained history
        final visited = <String, Set<String>>{};

        for (var session = 0; session < 16; session++) {
          final loop = practiceLoop(
            curriculum,
            history: log.take(variantWindow).toList(),
            lastUses: log,
          );
          for (final question in loop) {
            final variant = question.variant;
            if (variant == null) continue;
            (visited[variant.relationKey] ??= {}).add(variant.rootToken);
          }
          final next = historyFrom(
            loop,
            startSequence: log.isEmpty ? 1 : log.first.sequence + 1,
          );
          log.insertAll(0, next);
        }

        for (final exercise in exercises) {
          final pool = variantsFor(exercise);
          if (pool.isEmpty) continue;
          final key = pool.first.relationKey;
          final expected = pool.length < 16 ? pool.length : 16;
          expect(
            visited[key],
            hasLength(expected),
            reason:
                '$key has ${pool.length} roots but 16 sessions only reached '
                '${visited[key]?.length} of them',
          );
        }

        // The headline number, stated outright so a regression reads as one.
        expect(visited['interval:P1:asc'], hasLength(14));
        expect(visited['interval:P8:asc'], hasLength(2));
        expect(visited['scale:major:asc'], hasLength(1));
      },
    );

    test('a chord is byte-identical in every session', () async {
      final curriculum = await loadReal();
      var history = <VariantUse>[];
      final chordRefs = <List<String>>[];
      for (var session = 0; session < 5; session++) {
        final loop = practiceLoop(curriculum, history: history);
        chordRefs.add([
          for (final q in loop)
            if (q.type == ExerciseType.chord) ...q.audioSampleRefs,
        ]);
        for (final q in loop) {
          if (q.type == ExerciseType.chord) expect(q.variant, isNull);
        }
        history = historyFrom(
          loop,
          startSequence: history.isEmpty ? 1 : history.first.sequence + 1,
        );
      }
      for (final refs in chordRefs) {
        expect(refs, chordRefs.first);
      }
      // …and they are the catalog's own.
      expect(chordRefs.first, [
        for (final e in orderedExercises(curriculum))
          if (e is ChordExercise) ...e.audioSampleRefs,
      ]);
    });

    test(
      'every session it generates asks only for samples that exist',
      () async {
        final files = Directory('assets/audio')
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .toSet();
        final curriculum = await loadReal();
        var history = <VariantUse>[];
        for (var session = 0; session < 20; session++) {
          final loop = practiceLoop(curriculum, history: history);
          for (final question in loop) {
            for (final ref in question.audioSampleRefs) {
              expect(files, contains('$ref.wav'), reason: 'session $session');
            }
            // The motif is built off the refs, so it inherits the guarantee —
            // asserted anyway, because it is what actually reaches the player.
            for (final event in question.motif) {
              expect(files, contains('${event.ref}.wav'));
            }
          }
          history = historyFrom(
            loop,
            startSequence: history.isEmpty ? 1 : history.first.sequence + 1,
          );
        }
      },
    );

    test(
      'an unreadable history degrades to the catalog, never to a crash',
      () async {
        // The "database unavailable" row: the caller hands over `const []`.
        final curriculum = await loadReal();
        expect(practiceLoop(curriculum, history: const []).length, 39);
      },
    );

    test(
      'a history handed over in the wrong order is still read correctly',
      () async {
        final curriculum = await loadReal();
        final first = practiceLoop(curriculum);
        final newestFirst = historyFrom(first);
        final oldestFirst = newestFirst.reversed.toList();
        expect(
          practiceLoop(
            curriculum,
            history: oldestFirst,
          ).map((q) => q.audioSampleRefs).toList(),
          practiceLoop(
            curriculum,
            history: newestFirst,
          ).map((q) => q.audioSampleRefs).toList(),
        );
      },
    );
  });
}
