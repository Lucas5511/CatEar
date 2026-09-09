/// Public surface of the `core` module.
///
/// Exposes only: design tokens, [CatText], [appTheme], [AppDatabase] + its DAOs
/// and [databaseProvider]. Drift-generated models/tables never appear outside
/// this module — [RecentVariantsDao] hands back plain records for that reason.
library;

export 'database/app_database.dart' show AppDatabase;
export 'database/database_provider.dart' show databaseProvider;
export 'database/recent_variants.dart'
    show RecentVariantsDao, recentVariantsRetained;
export 'theme/app_theme.dart' show appTheme;
export 'theme/tokens.dart' show CatColors, CatRadii, CatSpacing;
export 'theme/typography.dart' show CatText;
export 'theme/wcag.dart' show contrastRatio, relativeLuminance;
