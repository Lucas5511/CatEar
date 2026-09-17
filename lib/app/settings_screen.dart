import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import 'app_version.dart';
import 'theme_mode_controller.dart';

/// Settings tab: "Tema", "Microfone" and "Sobre" (Story 1.10).
///
/// Everything on it is either a choice that applies immediately and is
/// remembered, or a plain fact about the build. No account, no login, nothing
/// that asks for a permission — the microphone row is a signpost for Epic 3,
/// deliberately inert.
///
/// Laid out as a [ListView] of full-width rows so nothing can overflow
/// vertically at a large `TextScaler`, and so every row is a ≥ 48 dp target
/// that grows with the text instead of clipping it.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Floor for every row, so a tap target never falls below the 48 dp the
  /// accessibility baseline asks for, whatever the text scale does.
  static const double _minRowHeight = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);
    final version = ref.watch(appVersionProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: CatSpacing.x2),
        children: [
          const _SectionHeader('Tema'),
          RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (m) {
              if (m != null) controller.set(m);
            },
            // Each radio carries its own role and checked state in semantics,
            // and the whole row is the label and the target.
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Claro'),
                  minTileHeight: _minRowHeight,
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Escuro'),
                  minTileHeight: _minRowHeight,
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('Seguir o sistema'),
                  minTileHeight: _minRowHeight,
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Microfone'),
          // Epic 3 fills this in. Disabled rather than absent, so the feature
          // is discoverable before it exists — and `enabled: false` is what
          // makes a screen reader announce it as unavailable, so the subtitle
          // explains rather than being the only clue. Epic 1 asks for no
          // permission and offers no link to the system settings.
          const ListTile(
            enabled: false,
            leading: Icon(Icons.mic_none_outlined),
            title: Text('Microfone'),
            subtitle: Text('Chega com a produção vocal'),
            minTileHeight: _minRowHeight,
          ),
          const Divider(),
          const _SectionHeader('Sobre'),
          ListTile(
            title: const Text('Versão'),
            // Under the label, not in `trailing`: a trailing value shares one
            // row with the label and is the first thing to overflow at
            // TextScaler 2.0.
            subtitle: Text(
              version.when(
                data: (v) => v,
                // Blank, not "—", while the lookup is in flight: the row would
                // otherwise spend its first frames claiming the version cannot
                // be read when it simply is not back yet.
                loading: () => '',
                error: (_, _) => unknownAppVersion,
              ),
            ),
            minTileHeight: _minRowHeight,
          ),
        ],
      ),
    );
  }
}

/// A section label, announced as a heading so a screen reader can jump between
/// the three sections instead of walking every row.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CatSpacing.x4,
        CatSpacing.x3,
        CatSpacing.x4,
        CatSpacing.x1,
      ),
      child: Semantics(
        header: true,
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
