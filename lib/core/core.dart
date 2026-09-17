/// Public surface of the `core` module.
///
/// Exposes only: design tokens, [CatText], [appTheme], the shared
/// [MascotBubble] widget (Story 1.9), [AppDatabase] + the DAOs modules reach it
/// through, [databaseProvider] and the shell's [ThemePreferenceRepository] port
/// (Story 1.10). Drift-generated models/tables never appear outside this module
/// — the DAOs hand back plain records and strings for that reason.
///
/// `PreferencesDao` is deliberately *not* here: `lib/app/` reaches the
/// preferences table through [ThemePreferenceRepository], so the DAO really is
/// "the only door into the table" its own doc claims it is.
library;

export 'database/app_database.dart' show AppDatabase;
export 'database/database_provider.dart' show databaseProvider;
export 'database/placements.dart' show PlacementsDao;
export 'database/recent_variants.dart'
    show RecentVariantsDao, recentVariantsRetained;
export 'preferences/theme_preference_repository.dart'
    show
        ThemePreferenceRepository,
        storedThemeModeProvider,
        themePreferenceRepositoryProvider;
export 'theme/app_theme.dart' show appTheme;
export 'theme/tokens.dart' show CatColors, CatRadii, CatSpacing;
export 'theme/typography.dart' show CatText;
export 'theme/wcag.dart' show contrastRatio, relativeLuminance;
export 'widgets/mascot_bubble.dart' show MascotBubble;
