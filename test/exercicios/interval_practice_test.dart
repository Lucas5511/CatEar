import 'package:catear/curriculo/curriculo.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixed loop (`practiceLoop`) and distractor pool (`practicePool`) against
/// the real `catalog_v1.json`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The v1 answer ids per type. Written out rather than derived from the pool
  /// so a catalog edit that silently drops or renames a spec fails here.
  const intervalIds = {
    'P1', 'm2', 'M2', 'm3', 'M3', 'P4', 'TT', 'P5', 'm6', 'M6', 'm7', 'M7',
    'P8', //
  };
  const chordIds = {'major', 'minor', 'diminished', 'augmented'};
  const scaleIds = {'major', 'natural_minor', 'dorian', 'mixolydian'};

  Future<Curriculum> loadReal() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(curriculoRepositoryProvider).load();
  }

  test('loop is every tappable exercise in stage order, nothing else', () async {
    final loop = practiceLoop(await loadReal());

    // Story 1.5 turned chord and scale on: 23 intervals + 8 chords + 8 scales.
    expect(loop.length, 39);
    expect(
      loop.where((q) => q.type == ExerciseType.interval).length,
      23,
      reason: 'the 23 interval exercises of v1, unchanged',
    );
    expect(loop.where((q) => q.type == ExerciseType.chord).length, 8);
    expect(loop.where((q) => q.type == ExerciseType.scale).length, 8);
    expect(
      loop.any((q) => q.type == ExerciseType.resolution),
      isFalse,
      reason: 'resolution is sung (Epic 3) and has no tap-to-answer surface',
    );
    expect(loop.first.answer.id, 'P1');
    // Since Story 1.8 the key carries the root as well as the direction, and
    // it is a String: an enum's hashCode is identity-based, which made
    // `optionSeed` — and the order of the buttons — differ per launch.
    expect(loop.first.variantKey, 'asc:sax_c4');
    expect(loop.last.answer.id, 'TT');
    expect(loop.last.variantKey, 'desc:sax_c4');

    // The catalog ships each of the 4 modes twice, asc and desc. Without a
    // `variantKey` the two would be equal under `==`/`hashCode` and share an
    // `optionSeed` — the collision the field exists to prevent.
    final scales = loop.where((q) => q.type == ExerciseType.scale).toList();
    final majorScales = scales.where((q) => q.answer.id == 'major').toList();
    expect(majorScales.length, 2);
    expect(majorScales.map((q) => q.variantKey).toSet(), {
      'asc:sax_c4',
      'desc:sax_c4',
    });
    expect(majorScales[0], isNot(majorScales[1]));
    expect(
      majorScales[0].optionSeed(0),
      isNot(majorScales[1].optionSeed(0)),
      reason: 'asc and desc must not share an option order',
    );
    expect(
      scales.map((q) => (q.answer.id, q.variantKey)).toSet().length,
      8,
      reason: '4 modes x 2 directions, all distinct',
    );
  });

  test('selection is by requiresVoice, not by a hand-kept type list', () async {
    // The two `resolution` exercises stay out because they are sung, and the
    // loop must not depend on `defaultPracticeTypes` happening to omit them:
    // naming the type explicitly still cannot put one on a card.
    final curriculum = await loadReal();
    final voiced = curriculum.stages
        .expand((s) => s.exercises)
        .where((e) => e.requiresVoice)
        .toList();
    expect(voiced.length, 2, reason: 'the catalog does contain sung exercises');

    expect(
      practiceLoop(curriculum, types: const {ExerciseType.resolution}),
      isEmpty,
    );
    expect(
      practiceLoop(curriculum, types: ExerciseType.values.toSet()).length,
      39,
      reason: 'even "every type" yields the 39 tappable ones',
    );
  });

  test('the pool is keyed by type — 13 / 4 / 4, never merged', () async {
    final pool = practicePool(await loadReal());

    expect(pool.keys.toSet(), {
      ExerciseType.interval,
      ExerciseType.chord,
      ExerciseType.scale,
    });
    // A loop invariant, not a catalog fact: 13 must not move because a new
    // exercise type was added. If it does, the pools have been merged.
    expect(pool[ExerciseType.interval]!.length, 13);
    expect(pool[ExerciseType.interval]!.map((o) => o.id).toSet(), intervalIds);
    expect(pool[ExerciseType.chord]!.map((o) => o.id).toSet(), chordIds);
    expect(pool[ExerciseType.scale]!.map((o) => o.id).toSet(), scaleIds);
    expect(pool[ExerciseType.interval]!.first.id, 'P1');

    for (final entry in pool.entries) {
      expect(
        entry.value.map((o) => o.id).toSet().length,
        entry.value.length,
        reason: 'no duplicates within ${entry.key}',
      );
    }
  });

  test('the `major` id in two catalogs stays two distinct options', () async {
    // `chordCatalog` and `scaleCatalog` both carry `id: "major"`. Keyed by type
    // they cannot collide; merged they would, and `_OptionButton` compares
    // `option.id == answer.id`, so a scale button would light up as the right
    // answer to a chord question.
    final pool = practicePool(await loadReal());
    final chordMajor = pool[ExerciseType.chord]!.firstWhere(
      (o) => o.id == 'major',
    );
    final scaleMajor = pool[ExerciseType.scale]!.firstWhere(
      (o) => o.id == 'major',
    );
    expect(chordMajor, isNot(scaleMajor));
    expect(chordMajor.nameUi, isNot(scaleMajor.nameUi));
  });

  test('loop content matches the catalog exercise by exercise', () async {
    final curriculum = await loadReal();
    final loop = practiceLoop(curriculum);

    // Content, not just cardinality: a loop of 39 questions built from the
    // wrong exercises would pass a bare length check.
    final stages = [...curriculum.stages]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.stageId.compareTo(b.stageId);
      });
    final expected = [
      for (final stage in stages)
        for (final e in stage.exercises)
          if (!e.requiresVoice)
            switch (e) {
              IntervalExercise() => (ExerciseType.interval, e.interval.id),
              ChordExercise() => (ExerciseType.chord, e.chord.id),
              ScaleExercise() => (ExerciseType.scale, e.scale.id),
              ResolutionExercise() => (ExerciseType.resolution, e.cadence.id),
            },
    ];
    expect(loop.map((q) => (q.type, q.answer.id)).toList(), expected);
  });

  test('loop honours stage.order even if stages come pre-sorted', () async {
    final loop = practiceLoop(await loadReal());
    // P1/P8/P5 (order 1) precede the thirds (3) precede the chords (4) precede
    // the scales (6) precede the tritone (10).
    final ids = loop.map((q) => q.answer.id).toList();
    final types = loop.map((q) => q.type).toList();
    expect(ids.indexOf('P1') < ids.indexOf('M3'), isTrue);
    expect(ids.indexOf('M3') < types.indexOf(ExerciseType.chord), isTrue);
    expect(
      types.indexOf(ExerciseType.chord) < types.indexOf(ExerciseType.scale),
      isTrue,
    );
    expect(types.indexOf(ExerciseType.scale) < ids.indexOf('TT'), isTrue);
  });

  test('a question carries the motif contour for its own type', () async {
    final loop = practiceLoop(await loadReal());

    final interval = loop.firstWhere((q) => q.type == ExerciseType.interval);
    expect(interval.motif.map((e) => e.ref).toList(), [
      interval.audioSampleRefs[0],
      interval.audioSampleRefs[1],
      interval.audioSampleRefs[0],
    ]);
    expect(interval.motifTotal, const Duration(milliseconds: 1800));

    final chord = loop.firstWhere((q) => q.type == ExerciseType.chord);
    // `[block, root, third, fifth]` -> block, arpeggio, block.
    expect(chord.audioSampleRefs.length, 4);
    expect(chord.motif.map((e) => e.ref).toList(), [
      chord.audioSampleRefs[0],
      chord.audioSampleRefs[1],
      chord.audioSampleRefs[2],
      chord.audioSampleRefs[3],
      chord.audioSampleRefs[0],
    ]);

    final scale = loop.firstWhere((q) => q.type == ExerciseType.scale);
    expect(scale.audioSampleRefs.length, 8);
    expect(scale.motif.map((e) => e.ref).toList(), scale.audioSampleRefs);
    // The whole point of a per-type rhythm: at the interval gap those 8 notes
    // would run 3.6 s and stop being heard as a scale.
    expect(
      scale.motifTotal.inMilliseconds,
      inInclusiveRange(2000, 2400),
      reason: 'a scale walks at ~250-300 ms/note, landing at ~2.0-2.4 s',
    );
    for (final event in scale.motif.take(scale.motif.length - 1)) {
      expect(event.hold.inMilliseconds, inInclusiveRange(250, 300));
    }
    // The chord's block rings longer than its arpeggio notes.
    expect(chord.motif.first.hold, greaterThan(chord.motif[1].hold));
    expect(chord.motif.last.hold, greaterThan(chord.motif[1].hold));
  });

  test('every question offers only options of its own type', () async {
    final curriculum = await loadReal();
    final loop = practiceLoop(curriculum);
    final pool = practicePool(curriculum);

    const idsByType = {
      ExerciseType.interval: intervalIds,
      ExerciseType.chord: chordIds,
      ExerciseType.scale: scaleIds,
    };

    for (var i = 0; i < loop.length; i++) {
      final question = loop[i];
      final options = answerOptionsForQuestion(
        question,
        pool,
        seed: question.optionSeed(i),
      );
      expect(options.length, 4, reason: 'position $i');
      expect(options, contains(question.answer), reason: 'position $i');
      for (final option in options) {
        // Identity, not just the id: chord `major` and scale `major` share an
        // id but are different options, so `contains` is the strict check.
        expect(
          pool[question.type]!,
          contains(option),
          reason:
              'position $i (${question.type.name}) offered ${option.id} '
              'from another catalog',
        );
        expect(
          option.id,
          isIn(idsByType[question.type]!),
          reason: 'position $i',
        );
      }
    }
  });

  test('GOLDEN: the interval option SET is the one Story 1.4 shipped', () async {
    // The alternatives offered for an interval must not have moved: mixing the
    // pools would put "tríade maior" (profile [4, 7], distance 3 from a major
    // third) ahead of most intervals. These sets were captured from the loop
    // before Story 1.5 turned chord and scale on.
    const frozenSelection = <String, Set<String>>{
      'P1': {'M2', 'P1', 'm2', 'm3'},
      'm2': {'M2', 'P1', 'm2', 'm3'},
      'M2': {'M2', 'M3', 'm2', 'm3'},
      'm3': {'M2', 'M3', 'P4', 'm3'},
      'M3': {'M2', 'M3', 'P4', 'm3'},
      'P4': {'M3', 'P4', 'P5', 'TT'},
      'TT': {'M3', 'P4', 'P5', 'TT'},
      'P5': {'M6', 'P5', 'TT', 'm6'},
      'm6': {'M6', 'P5', 'TT', 'm6'},
      'M6': {'M6', 'M7', 'm6', 'm7'},
      'm7': {'M6', 'M7', 'P8', 'm7'},
      'M7': {'M6', 'M7', 'P8', 'm7'},
      'P8': {'M6', 'M7', 'P8', 'm7'},
    };

    final curriculum = await loadReal();
    final loop = practiceLoop(curriculum);
    final pool = practicePool(curriculum);

    for (var i = 0; i < loop.length; i++) {
      final question = loop[i];
      if (question.type != ExerciseType.interval) continue;
      expect(
        answerOptionsForQuestion(
          question,
          pool,
          seed: question.optionSeed(i),
        ).map((o) => o.id).toSet(),
        frozenSelection[question.answer.id],
        reason: 'the alternatives for ${question.answer.id} moved',
      );
    }
  });

  test('GOLDEN: option selection and ordering are frozen', () async {
    // A determinism-only assertion cannot guard the ranking: any seed formula
    // is deterministic for a fixed seed. So two goldens:
    //
    //  * ORDERING, with an explicit seed — the ranking + shuffle, and what a
    //    refactor of `answerOptionsFor` would move.
    //  * ORDERING through the real `optionSeed` — see the test below. Story 1.8
    //    made that half freezable for the first time: `optionSeed` used to hash
    //    a `Direction` enum, whose hashCode is identity-based and re-randomised
    //    per isolate (measured 2026-09-05: the same position yielded seeds
    //    489118127 / 15087377 / 409236786 across three runs), so the order on
    //    screen changed on every launch.
    //
    // Regenerated for Story 1.5: the loop is 39 long, so the interval
    // positions sit at different indices and the shuffle input moved. The
    // option *sets* did not — see the golden above.
    const orderedBySeedIndex = <String>[
      'm2,P1,M2,m3', // interval
      'm7,M7,M6,P8', // interval
      'M6,m6,P5,TT', // interval
      'P4,M3,m3,M2', // interval
      'M2,P4,M3,m3', // interval
      'M2,M3,P4,m3', // interval
      'm3,P4,M3,M2', // interval
      'augmented,diminished,minor,major', // chord
      'augmented,major,diminished,minor', // chord
      'diminished,minor,major,augmented', // chord
      'augmented,minor,major,diminished', // chord
      'diminished,augmented,major,minor', // chord
      'augmented,minor,major,diminished', // chord
      'diminished,major,augmented,minor', // chord
      'minor,major,augmented,diminished', // chord
      'M2,M3,m3,m2', // interval
      'm3,M3,M2,m2', // interval
      'm3,M2,m2,P1', // interval
      'M2,P1,m2,m3', // interval
      'mixolydian,dorian,natural_minor,major', // scale
      'major,dorian,mixolydian,natural_minor', // scale
      'dorian,mixolydian,natural_minor,major', // scale
      'major,mixolydian,natural_minor,dorian', // scale
      'major,mixolydian,natural_minor,dorian', // scale
      'mixolydian,natural_minor,major,dorian', // scale
      'dorian,natural_minor,mixolydian,major', // scale
      'natural_minor,mixolydian,major,dorian', // scale
      'TT,M3,P5,P4', // interval
      'P5,P4,TT,M3', // interval
      'M6,m6,m7,M7', // interval
      'm6,M6,M7,m7', // interval
      'P5,TT,M6,m6', // interval
      'M6,m6,TT,P5', // interval
      'M7,P8,m7,M6', // interval
      'm7,M6,P8,M7', // interval
      'P8,m7,M6,M7', // interval
      'M7,P8,M6,m7', // interval
      'P5,TT,M3,P4', // interval
      'M3,TT,P4,P5', // interval
    ];

    final curriculum = await loadReal();
    final loop = practiceLoop(curriculum);
    final pool = practicePool(curriculum);
    expect(loop.length, orderedBySeedIndex.length);

    for (var i = 0; i < loop.length; i++) {
      expect(
        answerOptionsForQuestion(
          loop[i],
          pool,
          seed: i,
        ).map((o) => o.id).join(','),
        orderedBySeedIndex[i],
        reason: 'ranking or shuffle moved at loop position $i',
      );
      expect(
        answerOptionsForQuestion(
          loop[i],
          pool,
          seed: loop[i].optionSeed(i),
        ).map((o) => o.id).toSet(),
        answerOptionsForQuestion(
          loop[i],
          pool,
          seed: i,
        ).map((o) => o.id).toSet(),
        reason: 'the chosen 4 must not depend on the seed, only their order',
      );
    }
  });

  test('GOLDEN: the option ORDER on screen is the same in every process', () {
    // The literals below were produced by a *different* process. A run that
    // agrees with them is the cross-process guarantee the story owes; a run
    // that computes its own expectation would agree with any formula, which is
    // exactly how the enum-hashCode instability survived three stories.
    expect(stableSeed(''), 0);
    expect(stableSeed('M3|asc:sax_c4|0'), 985624910);
    expect(stableSeed('M3|desc:sax_c4|0'), 1523439576);
    expect(stableSeed('major|asc:sax_c4|19'), 438355059);
    // Different index, different variation, different relation -> different
    // seed. (Not a hash-quality claim; just that all three reach the seed.)
    expect(stableSeed('M3|asc:sax_c4|1'), isNot(stableSeed('M3|asc:sax_c4|0')));
    expect(stableSeed('M3|asc:sax_d4|0'), isNot(stableSeed('M3|asc:sax_c4|0')));
  });

  test(
    'GOLDEN: the whole loop\'s option order, through the real seed',
    () async {
      // Frozen for the first time in Story 1.8 — see the test above for why it
      // could not be frozen before. Regenerate deliberately, never to "fix" a
      // red run: a change here is a change to what the learner sees.
      const orderedByRealSeed = <String>[
        'm2,m3,P1,M2', // interval
        'M7,P8,m7,M6', // interval
        'TT,P5,m6,M6', // interval
        'm3,P4,M2,M3', // interval
        'P4,m3,M2,M3', // interval
        'P4,M2,M3,m3', // interval
        'M2,m3,P4,M3', // interval
        'major,augmented,diminished,minor', // chord
        'augmented,major,minor,diminished', // chord
        'augmented,minor,major,diminished', // chord
        'major,minor,augmented,diminished', // chord
        'major,minor,diminished,augmented', // chord
        'minor,major,diminished,augmented', // chord
        'augmented,diminished,major,minor', // chord
        'augmented,major,diminished,minor', // chord
        'm3,m2,M3,M2', // interval
        'M3,M2,m2,m3', // interval
        'm2,M2,m3,P1', // interval
        'm3,P1,m2,M2', // interval
        'natural_minor,dorian,major,mixolydian', // scale
        'major,natural_minor,mixolydian,dorian', // scale
        'major,mixolydian,natural_minor,dorian', // scale
        'mixolydian,major,natural_minor,dorian', // scale
        'dorian,major,mixolydian,natural_minor', // scale
        'dorian,natural_minor,mixolydian,major', // scale
        'mixolydian,natural_minor,major,dorian', // scale
        'natural_minor,mixolydian,dorian,major', // scale
        'M3,TT,P4,P5', // interval
        'M3,P5,P4,TT', // interval
        'M7,m6,M6,m7', // interval
        'm6,M7,M6,m7', // interval
        'P5,m6,TT,M6', // interval
        'M6,TT,P5,m6', // interval
        'P8,M6,M7,m7', // interval
        'P8,M7,M6,m7', // interval
        'm7,M7,M6,P8', // interval
        'M7,P8,m7,M6', // interval
        'TT,P4,M3,P5', // interval
        'P4,P5,TT,M3', // interval
      ];

      final curriculum = await loadReal();
      // No history: the first session of a fresh install, which is the only
      // loop whose refs — and therefore whose variantKeys — are fixed.
      final loop = practiceLoop(curriculum);
      final pool = practicePool(curriculum);
      expect(loop.length, orderedByRealSeed.length);

      for (var i = 0; i < loop.length; i++) {
        expect(
          answerOptionsForQuestion(
            loop[i],
            pool,
            seed: loop[i].optionSeed(i),
          ).map((o) => o.id).join(','),
          orderedByRealSeed[i],
          reason: 'the option order moved at loop position $i',
        );
      }
    },
  );

  test('a single type still flows through the same machinery', () async {
    final curriculum = await loadReal();

    final chords = practiceLoop(curriculum, types: const {ExerciseType.chord});
    expect(chords.length, 8);
    expect(chords.every((q) => q.type == ExerciseType.chord), isTrue);
    expect(chords.first.prompt, 'Que acorde é este?');
    expect(
      practicePool(curriculum, types: const {ExerciseType.chord}).keys.toSet(),
      {ExerciseType.chord},
    );

    final scales = practiceLoop(curriculum, types: const {ExerciseType.scale});
    expect(scales.length, 8);
    expect(scales.every((q) => q.type == ExerciseType.scale), isTrue);
    expect(scales.first.prompt, 'Que escala é esta?');
    expect(
      practicePool(curriculum, types: const {ExerciseType.scale}).keys.toSet(),
      {ExerciseType.scale},
    );
  });
}
