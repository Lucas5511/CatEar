/// Drift-backed [VariantHistoryRepository].
///
/// The implementation class is library-private: the only public symbol is
/// [variantHistoryRepositoryProvider], re-exported by the module barrel — the
/// same shape `curriculo/data/` uses. The database is reached through the
/// `core.dart` barrel and its DAO (Rule 2 of `check_module_boundaries`), and no
/// Drift-generated symbol crosses into `domain/`: the DAO hands back records,
/// which this file maps onto [VariantUse].
library;

import 'package:catear/core/core.dart';
import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/variant_history.dart';

part 'variant_history_repository_impl.g.dart';

/// Provides the recent-variation history. Consumers depend only on this.
///
/// It watches `databaseProvider.future` rather than its `AsyncValue`: opening
/// the database is asynchronous and may fail, and every method here already has
/// to be a `Future`. A failed open therefore surfaces as a rejected future from
/// [VariantHistoryRepository.recent] / `.record`, which is the failure the
/// caller is expected to degrade around — not as a provider the practice screen
/// would have to wait on before it could show an exercise.
@riverpod
VariantHistoryRepository variantHistoryRepository(Ref ref) =>
    _DriftVariantHistoryRepository(ref.watch(databaseProvider.future));

class _DriftVariantHistoryRepository implements VariantHistoryRepository {
  _DriftVariantHistoryRepository(this._database);

  final Future<AppDatabase> _database;

  /// Tail of the write chain. Writes are fired without being awaited (a
  /// database round-trip must never sit between the learner and the next
  /// exercise), and `sequence` is what the whole window is ordered by, so they
  /// have to land in call order.
  Future<void> _writes = Future<void>.value();

  Future<RecentVariantsDao> get _dao async =>
      RecentVariantsDao(await _database);

  /// Waits for every write already fired to land, swallowing their failures —
  /// a failed write is reported to whoever called [record], and must not turn
  /// a read into an error.
  ///
  /// Every read goes through this. Writes are deliberately fired without being
  /// awaited, so without it a read issued right after them would see a history
  /// that is missing its newest rows — which is exactly the window the next
  /// session's choice is made from.
  Future<void> get _settled => _writes.then((_) {}, onError: (_, _) {});

  @override
  Future<List<VariantUse>> recent({required int limit}) async {
    if (limit <= 0) return const [];
    await _settled;
    final rows = await (await _dao).mostRecent(limit);
    return [
      for (final row in rows)
        VariantUse(
          relationKey: row.relationKey,
          rootToken: row.rootToken,
          sequence: row.sequence,
        ),
    ];
  }

  @override
  Future<List<VariantUse>> lastUsePerRoot() async {
    await _settled;
    final rows = await (await _dao).lastUsePerRoot();
    return [
      for (final row in rows)
        VariantUse(
          relationKey: row.relationKey,
          rootToken: row.rootToken,
          sequence: row.sequence,
        ),
    ];
  }

  @override
  Future<void> record({
    required String relationKey,
    required String rootToken,
  }) {
    final write = _writes.then((_) async {
      final dao = await _dao;
      await dao.record(
        relationKey: relationKey,
        rootToken: rootToken,
        // `clock`, not `DateTime.now()`, so a test can pin the value like
        // every other time-dependent seam in the app.
        usedAt: clock.now(),
      );
    });
    // The chain must not be poisoned by one failure: the next write still has
    // to be attempted, and the failure is reported to whoever called `record`.
    _writes = write.then((_) {}, onError: (_, _) {});
    return write;
  }
}
