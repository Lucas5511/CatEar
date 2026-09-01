import 'package:flutter/material.dart';

import '../progressao/progressao.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// The app shell: a 4-tab bottom [NavigationBar] over an [IndexedStack].
///
/// No `Drawer`, no swipe navigation (no `PageView`). The Android back button
/// on any tab other than Home returns to Home instead of leaving the app.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['CatEar', 'Trilha', 'Progresso', 'Ajustes'];

  static const _screens = [
    HomeScreen(),
    SkillTreePlaceholderScreen(),
    ProgressPlaceholderScreen(),
    SettingsScreen(),
  ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_titles[_index])),
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              selectedIcon: Icon(Icons.account_tree),
              label: 'Trilha',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Progresso',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
