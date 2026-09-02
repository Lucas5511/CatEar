/// Public barrel for the `curriculo` module.
///
/// Re-exports the domain models + taxonomy + the repository port, plus the
/// single provider from `data/`. Nothing else touches `data/` or reads the
/// asset. `presentation/` is empty in this story.
library;

export 'data/curriculo_repository_impl.dart' show curriculoRepositoryProvider;
export 'domain/catalogs.dart';
// Exposes CurriculoRepository plus the CurriculumError hierarchy it re-exports.
export 'domain/curriculo_repository.dart';
export 'domain/curriculum.dart';
export 'domain/enums.dart';
