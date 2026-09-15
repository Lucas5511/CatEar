/// Drift-backed [PlacementRepository] and the read provider the boot gate
/// watches.
///
/// The implementation class is library-private: the public symbols are
/// [placementRepositoryProvider] (the port, for the levelling to write through)
/// and [placementProvider] (the current level, for the gate to read), both
/// re-exported by the module barrel — the same shape
/// `variant_history_repository_impl.dart` uses. The database is reached
/// through the `core.dart` barrel and its DAO (Rule 2 of
/// `check_module_boundaries`), and no Drift-generated symbol crosses into
/// `domain/`: the DAO hands back a record, which this file maps onto
/// [Placement].
library;

import 'package:catear/core/core.dart';
import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/placement.dart';

part 'placement_repository_impl.g.dart';

/// Provides the starting-level port. The levelling depends only on this.
///
/// Watches `databaseProvider.future` rather than its `AsyncValue`, like the
/// variation history: a failed open surfaces as a rejected future from
/// [PlacementRepository.current] / `.record`, which each caller degrades
/// around in its own way.
@riverpod
PlacementRepository placementRepository(Ref ref) =>
    _DriftPlacementRepository(ref.watch(databaseProvider.future));

/// No automatic retry: Riverpod 3's default retries any thrown `Exception`
/// with backoff (~38 s in all) while the state stays `AsyncLoading` — the boot
/// screen would spin for half a minute before the error screen and its own
/// retry appeared.
Duration? _noRetry(int retryCount, Object error) => null;

/// The recorded starting level, or `null` on first use.
///
/// What `CatEarApp`'s entry gate watches once the database is open: `null`
/// routes to the levelling, a value to the shell. Auto-dispose, so it is
/// re-read on the next boot rather than cached across one.
@Riverpod(retry: _noRetry)
Future<Placement?> placement(Ref ref) =>
    ref.watch(placementRepositoryProvider).current();

class _DriftPlacementRepository implements PlacementRepository {
  _DriftPlacementRepository(this._database);

  final Future<AppDatabase> _database;

  Future<PlacementsDao> get _dao async => PlacementsDao(await _database);

  @override
  Future<Placement?> current() async {
    final row = await (await _dao).current();
    if (row == null) return null;
    return Placement(
      stageId: row.stageId,
      correctCount: row.correctCount,
      recordedAt: DateTime.parse(row.recordedAt).toUtc(),
    );
  }

  @override
  Future<void> record({
    required String stageId,
    required int correctCount,
  }) async {
    final dao = await _dao;
    await dao.record(
      stageId: stageId,
      correctCount: correctCount,
      // `clock`, not `DateTime.now()`, so a test can pin the value like every
      // other time-dependent seam in the app.
      recordedAt: clock.now(),
    );
  }
}
