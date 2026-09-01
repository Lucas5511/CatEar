/// Public surface of the `core` module.
///
/// Exposes only: design tokens, [CatText], [appTheme], [AppDatabase] (+ future
/// DAOs) and [databaseProvider]. Drift-generated models/tables never appear
/// outside this module.
library;

export 'database/app_database.dart' show AppDatabase;
export 'database/database_provider.dart' show databaseProvider;
export 'theme/app_theme.dart' show appTheme;
export 'theme/tokens.dart' show CatColors, CatRadii, CatSpacing;
export 'theme/typography.dart' show CatText;
export 'theme/wcag.dart' show contrastRatio, relativeLuminance;
