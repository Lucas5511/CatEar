import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_controller.dart';

/// Settings tab. Story 1.1 ships the theme selector (applied immediately) and
/// an "About" line with the app version. The full screen — including the
/// reserved "Microphone" item (Epic 3) — is Story 1.10.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // App version. Story 1.10 replaces this with a real package-info lookup.
  static const _version = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tema', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (m) {
              if (m != null) controller.set(m);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Claro'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Escuro'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('Seguir o sistema'),
                ),
              ],
            ),
          ),
          const Divider(),
          Text('Sobre', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(title: const Text('Versão'), trailing: Text(_version)),
        ],
      ),
    );
  }
}
