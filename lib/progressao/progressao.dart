/// Public barrel for the `progressao` module.
///
/// Re-exports domain symbols — since Story 1.8 the recent-variation history,
/// since Story 1.9 the starting level, both owned by this module (AD-2) — plus
/// the providers from `data/` and the route screens that the app shell mounts
/// as tabs. Non-route `presentation/` and the rest of `data/` stay
/// module-private.
///
/// `exercicios/` reaches the history, and `nivelamento/` and the app's entry
/// gate reach the level, only through this file.
library;

export 'data/placement_repository_impl.dart'
    show placementProvider, placementRepositoryProvider;
export 'data/variant_history_repository_impl.dart'
    show variantHistoryRepositoryProvider;
export 'domain/placement.dart';
export 'domain/variant_history.dart';
export 'presentation/progress_placeholder_screen.dart'
    show ProgressPlaceholderScreen;
export 'presentation/skill_tree_placeholder_screen.dart'
    show SkillTreePlaceholderScreen;
