/// Public barrel for the `nivelamento` module (Story 1.9).
///
/// Re-exports the pure `domain/` (the fixed sequence, the option rule for the
/// easy opener, the level rule and the stage names) and, from `presentation/`,
/// the one route screen the app's entry gate mounts on first use. The notifier
/// stays a presentation internal.
library;

export 'domain/placement_sequence.dart';
export 'presentation/nivelamento_screen.dart' show NivelamentoScreen;
