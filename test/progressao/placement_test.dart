import 'package:catear/core/core.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Story 1.9 — the storage half of the starting level.
///
/// The Progressão module owns this state (AD-2): these tests drive the real
/// `placementRepositoryProvider` against a real in-memory Drift database,
/// through the module's public port only. The DAO is reached (via the `core`
/// barrel) solely to count rows — nothing here names a Drift-generated symbol.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  /// A container whose `databaseProvider` is an in-memory database.
  ///
  /// [failing] makes the open throw instead, which is the "database
  /// unavailable" row of the matrix.
  ProviderContainer containerWith({bool failing = false}) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async {
          if (failing) throw StateError('simulated open failure');
          db = AppDatabase(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  PlacementRepository repoOf(ProviderContainer c) =>
      c.read(placementRepositoryProvider);

  test('a fresh install has no level, and that is not an error', () async {
    expect(await repoOf(containerWith()).current(), isNull);
  });

  test('a second record replaces the first: one row, the later one', () async {
    final repo = repoOf(containerWith());
    await repo.record(stageId: 's-consonancias', correctCount: 0);
    await repo.record(stageId: 's-quarta', correctCount: 3);

    expect(await db.placementsDao.countAll(), 1);
    final current = await repo.current();
    expect(current?.stageId, 's-quarta');
    expect(current?.correctCount, 3);
  });

  test('recordedAt comes from `clock` and is stored as the UTC instant, '
      'whatever zone the clock is in', () async {
    final repo = repoOf(containerWith());
    // A local-time value (no `isUtc`), as a device clock hands it over.
    final local = DateTime(2026, 9, 15, 14, 30);
    await withClock(
      Clock.fixed(local),
      () => repo.record(stageId: 's-tercas', correctCount: 2),
    );

    final current = await repo.current();
    expect(current?.recordedAt.isUtc, isTrue);
    expect(current?.recordedAt, local.toUtc());
    expect(current?.recordedAt.isAtSameMomentAs(local), isTrue);
  });

  test('an unavailable database rejects both reads and writes', () async {
    final repo = repoOf(containerWith(failing: true));

    await expectLater(repo.current(), throwsA(isA<StateError>()));
    await expectLater(
      repo.record(stageId: 's-tercas', correctCount: 1),
      throwsA(isA<StateError>()),
    );
  });
}
