/// Public barrel for the `progressao` module.
///
/// Re-exports domain symbols and the route screens that the app shell mounts
/// as tabs. Non-route `presentation/` and all `data/` stay module-private.
library;

export 'presentation/progress_placeholder_screen.dart'
    show ProgressPlaceholderScreen;
export 'presentation/skill_tree_placeholder_screen.dart'
    show SkillTreePlaceholderScreen;
