/// Public barrel for the `progressao` module.
///
/// Re-exports domain symbols — since Story 1.8, the recent-variation history
/// this module owns (AD-2) — plus the single provider from `data/` and the
/// route screens that the app shell mounts as tabs. Non-route `presentation/`
/// and the rest of `data/` stay module-private.
///
/// `exercicios/` reaches the history only through this file.
library;

export 'data/variant_history_repository_impl.dart'
    show variantHistoryRepositoryProvider;
export 'domain/variant_history.dart';
export 'presentation/progress_placeholder_screen.dart'
    show ProgressPlaceholderScreen;
export 'presentation/skill_tree_placeholder_screen.dart'
    show SkillTreePlaceholderScreen;
