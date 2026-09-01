import 'package:catear/app/cat_ear_app.dart';
import 'package:catear/app/database_error_screen.dart';
import 'package:catear/app/home_shell.dart';
import 'package:catear/app/theme_mode_controller.dart';
import 'package:catear/core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loading -> boot screen, then data -> HomeShell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const CatEarApp(),
      ),
    );

    // Still resolving.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(DatabaseErrorScreen), findsNothing);
  });

  testWidgets('error -> DatabaseErrorScreen; retry -> HomeShell', (
    tester,
  ) async {
    var shouldFail = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async {
            if (shouldFail) {
              throw StateError('boom');
            }
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DatabaseErrorScreen), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);

    // The retry button invalidates the provider; now let it succeed.
    shouldFail = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byType(DatabaseErrorScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('system dark platform brightness -> dark theme, no restart', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('picking "Escuro" in Settings switches brightness live', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async {
            final db = AppDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            return db;
          }),
        ],
        child: const CatEarApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Light by default (test platform brightness is light).
    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(HomeShell))).brightness,
      Brightness.dark,
    );
  });

  test('themeModeProvider defaults to system', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });
}
