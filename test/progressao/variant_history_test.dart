import 'dart:async';

import 'package:catear/core/core.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Story 1.8 — the storage half of the anti-decoreba history.
///
/// The Progressão module owns this state (AD-2): these tests drive the real
/// `variantHistoryRepositoryProvider` against a real in-memory Drift database,
/// through the module's public port only. Nothing here names a Drift-generated
/// symbol, which is the boundary the barrel is supposed to hold.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A container whose `databaseProvider` is an in-memory database.
  ///
  /// [failing] makes the open throw instead, which is the "database
  /// unavailable" row of the matrix.
  ProviderContainer containerWith({bool failing = false}) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async {
          if (failing) throw StateError('simulated open failure');
          final db = AppDatabase(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  VariantHistoryRepository repoOf(ProviderContainer c) =>
      c.read(variantHistoryRepositoryProvider);

  test('a fresh install has no history, and that is not an error', () async {
    expect(await repoOf(containerWith()).recent(limit: 39), isEmpty);
  });

  test(
    'what is recorded comes back newest first, with a total order',
    () async {
      final repo = repoOf(containerWith());
      await repo.record(relationKey: 'interval:M3:asc', rootToken: 'sax_c4');
      await repo.record(relationKey: 'interval:M3:asc', rootToken: 'sax_d4');
      await repo.record(relationKey: 'scale:dorian:asc', rootToken: 'sax_c4');

      final recent = await repo.recent(limit: 39);
      expect(recent.map((u) => (u.relationKey, u.rootToken)).toList(), [
        ('scale:dorian:asc', 'sax_c4'),
        ('interval:M3:asc', 'sax_d4'),
        ('interval:M3:asc', 'sax_c4'),
      ]);
      // Strictly decreasing: the whole selection rule reads this ordering.
      expect(recent[0].sequence, greaterThan(recent[1].sequence));
      expect(recent[1].sequence, greaterThan(recent[2].sequence));
    },
  );

  test('the limit is a window, not a filter', () async {
    final repo = repoOf(containerWith());
    for (var i = 0; i < 10; i++) {
      await repo.record(relationKey: 'interval:P5:asc', rootToken: 'root$i');
    }
    expect((await repo.recent(limit: 3)).map((u) => u.rootToken).toList(), [
      'root9',
      'root8',
      'root7',
    ]);
    expect(await repo.recent(limit: 0), isEmpty);
  });

  test('writes fired without awaiting still land in call order', () async {
    // How the practice screen calls it: one `record` per exercise presented,
    // never awaited, because a round-trip must not sit between the learner and
    // the next card. `sequence` is what the window is ordered by, so an
    // interleaved write would silently corrupt "least recently used".
    final repo = repoOf(containerWith());
    final fired = [
      for (var i = 0; i < 20; i++)
        repo.record(relationKey: 'interval:m2:asc', rootToken: 'root$i'),
    ];
    await Future.wait(fired);

    expect((await repo.recent(limit: 20)).map((u) => u.rootToken).toList(), [
      for (var i = 19; i >= 0; i--) 'root$i',
    ]);
  });

  test('the log does not grow without bound', () async {
    final repo = repoOf(containerWith());
    for (var i = 0; i < recentVariantsRetained + 25; i++) {
      await repo.record(relationKey: 'interval:P1:asc', rootToken: 'root$i');
    }
    final all = await repo.recent(limit: recentVariantsRetained * 2);
    expect(all.length, recentVariantsRetained);
    expect(all.first.rootToken, 'root${recentVariantsRetained + 24}');
    // The 39-exercise window is far inside what survives pruning, which is the
    // property that makes the cap safe.
    expect(all.length, greaterThan(39));
  });

  test('the recorded timestamp comes from the injectable clock', () async {
    // `usedAt` is diagnostics-only and deliberately absent from `VariantUse`,
    // which is exactly why this test has to reach past the port to the column:
    // asserting that the row came back proves nothing about what was written,
    // and `clock.now()` could quietly become `DateTime.now()` — or local time
    // instead of the UTC the storage convention requires — with every test
    // still green.
    final container = containerWith();
    final repo = repoOf(container);
    await withClock(Clock.fixed(DateTime.utc(2026, 9, 9, 12, 30)), () async {
      await repo.record(relationKey: 'interval:P8:asc', rootToken: 'sax_c4');
    });

    final db = await container.read(databaseProvider.future);
    expect(
      await RecentVariantsDao(db).latestUsedAt(),
      DateTime.utc(2026, 9, 9, 12, 30).toIso8601String(),
    );
  });

  test('a local-time clock is still stored as UTC', () async {
    // The convention is ISO 8601 **UTC** text. A `DateTime` that arrives with
    // an offset must be converted, not written as-is.
    final container = containerWith();
    final repo = repoOf(container);
    final local = DateTime.utc(2026, 9, 9, 15).toLocal();
    await withClock(Clock.fixed(local), () async {
      await repo.record(relationKey: 'interval:M3:asc', rootToken: 'sax_d4');
    });

    final db = await container.read(databaseProvider.future);
    final stored = await RecentVariantsDao(db).latestUsedAt();
    expect(stored, endsWith('Z'));
    expect(DateTime.parse(stored!).isUtc, isTrue);
    expect(DateTime.parse(stored), DateTime.utc(2026, 9, 9, 15));
  });

  test('every recorded root comes back with its latest use', () async {
    // The half of the history that orders the roots the window left free.
    // Grouped per (relation, root), and it must carry the *latest* sequence,
    // not the first — that is what tells a root heard long ago from one heard
    // last session.
    final repo = repoOf(containerWith());
    await repo.record(relationKey: 'interval:M3:asc', rootToken: 'sax_c4');
    await repo.record(relationKey: 'interval:M3:asc', rootToken: 'sax_d4');
    await repo.record(relationKey: 'interval:M3:asc', rootToken: 'sax_c4');
    await repo.record(relationKey: 'scale:dorian:asc', rootToken: 'sax_c4');

    final lastUses = await repo.lastUsePerRoot();
    expect(lastUses, hasLength(3), reason: 'one row per (relation, root)');
    int seqOf(String relation, String root) => lastUses
        .firstWhere((u) => u.relationKey == relation && u.rootToken == root)
        .sequence;
    expect(
      seqOf('interval:M3:asc', 'sax_c4'),
      greaterThan(seqOf('interval:M3:asc', 'sax_d4')),
      reason: 'sax_c4 played again after sax_d4, so it is the more recent',
    );
    expect(seqOf('scale:dorian:asc', 'sax_c4'), 4);
  });

  test('a read waits for the writes already fired', () async {
    // Writes are deliberately not awaited by the practice screen. A read that
    // did not wait for them would hand the next session a window missing its
    // newest rows — and the whole point of the window is to be current.
    final repo = repoOf(containerWith());
    unawaited(repo.record(relationKey: 'interval:P5:asc', rootToken: 'sax_c4'));
    unawaited(repo.record(relationKey: 'interval:P5:asc', rootToken: 'sax_d4'));

    expect(await repo.recent(limit: 39), hasLength(2));
    expect(await repo.lastUsePerRoot(), hasLength(2));
  });

  test('an unavailable database is reported, never swallowed', () async {
    // The repository does not decide to degrade — the practice screen does,
    // and it can only do that if the failure reaches it.
    final repo = repoOf(containerWith(failing: true));
    await expectLater(repo.recent(limit: 39), throwsStateError);
    await expectLater(
      repo.record(relationKey: 'interval:M3:asc', rootToken: 'sax_c4'),
      throwsStateError,
    );
    // …and a failed write does not poison the queue for the next one.
    await expectLater(
      repo.record(relationKey: 'interval:M3:asc', rootToken: 'sax_d4'),
      throwsStateError,
    );
  });
}
