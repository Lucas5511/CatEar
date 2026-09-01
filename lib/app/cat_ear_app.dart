import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import 'database_error_screen.dart';
import 'home_shell.dart';
import 'theme_mode_controller.dart';

/// Root widget: wires theming, localization and the database gate.
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
        data: (_) => const HomeShell(),
      ),
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
