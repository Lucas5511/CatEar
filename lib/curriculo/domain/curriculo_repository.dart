/// The curriculum port: a `Future<Curriculum> load()` that says nothing about
/// where the data comes from (asset today, OTA later).
library;

import 'curriculum.dart';
import 'curriculum_error.dart';

export 'curriculum_error.dart'
    show CurriculumError, AssetNotFound, MalformedCatalog, UnknownValue;

/// Loads and validates the curriculum catalog.
///
/// The implementation lives in `data/` and is library-private; consumers get it
/// through `curriculoRepositoryProvider` (re-exported by the module barrel).
abstract interface class CurriculoRepository {
  /// Reads the catalog, validates every structural / safety / taxonomy rule,
  /// and returns pure domain models.
  ///
  /// Completes with a [CurriculumError] (never a raw `FormatException` /
  /// `TypeError`) on any failure. Does **not** check `order` monotonicity or
  /// the fading invariants — those are the build gate's job
  /// (`tool/check_curriculum.dart`).
  Future<Curriculum> load();
}
