import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import '../nivelamento/nivelamento.dart';
import '../progressao/progressao.dart';
import 'database_error_screen.dart';
import 'home_shell.dart';
import 'theme_mode_controller.dart';

/// Root widget: wires theming, localization, the database gate and, behind
/// it, the first-use gate (Story 1.9).
class CatEarApp extends ConsumerWidget {
  const CatEarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final database = ref.watch(databaseProvider);

    return MaterialApp(
      title: 'CatEar',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: themeMode,
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: database.when(
        loading: () => const _BootScreen(),
        error: (_, _) => DatabaseErrorScreen(
          onRetry: () => ref.invalidate(databaseProvider),
        ),
        data: (_) => const _EntryGate(),
      ),
    );
  }
}

/// First use opens straight into the levelling (UX-DR12): with the database
/// open, this reads the starting level through the Progressão's `domain/` —
/// absent, the [NivelamentoScreen] fills the screen (no tab bar, no login);
/// present, the [HomeShell].
///
/// Stateful for the hand-off: the levelling says it is done through a
/// callback and this switches to the shell *in place* — no route is pushed,
/// so back can never return to the levelling, and it works even when the
/// level's write failed (the summary is shown regardless; the next boot simply
/// re-reads the database and finds nothing). A levelling left mid-way
/// persists nothing and starts over next time.
class _EntryGate extends ConsumerStatefulWidget {
  const _EntryGate();

  @override
  ConsumerState<_EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends ConsumerState<_EntryGate> {
  bool _levelled = false;

  @override
  Widget build(BuildContext context) {
    if (_levelled) return const HomeShell();
    final placement = ref.watch(placementProvider);
    return placement.when(
      loading: () => const _BootScreen(),
      // The database is open, so a failed read is the same class of problem
      // as a failed open: same screen. Retry reopens the database as well —
      // a dead connection re-read on the same handle would fail forever —
      // and the read re-runs on the new one (`placementRepositoryProvider`
      // watches `databaseProvider.future`).
      error: (_, _) => DatabaseErrorScreen(
        onRetry: () {
          ref.invalidate(databaseProvider);
          ref.invalidate(placementProvider);
        },
      ),
      data: (placement) => placement == null
          ? NivelamentoScreen(onDone: () => setState(() => _levelled = true))
          : const HomeShell(),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
