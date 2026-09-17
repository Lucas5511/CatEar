import 'package:catear/app/home_shell.dart';
import 'package:catear/core/core.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The shell builds every tab eagerly (`IndexedStack`), so Settings — and with
/// it the theme preference and the version lookup — is alive in every test
/// here. Both are given something real to talk to: without the overrides these
/// tests would pass only because the missing `path_provider` and
/// `package_info` channels throw and the failures are swallowed.
Widget _app() => ProviderScope(
  overrides: [
    databaseProvider.overrideWith((ref) async {
      final db = AppDatabase(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    }),
  ],
  child: MaterialApp(
    theme: appTheme(Brightness.light),
    home: const HomeShell(),
  ),
);

NavigationBar _navBar(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'CatEar',
      packageName: 'app.catear',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('starts on the Home tab', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('Que bom ter você no CatEar!'), findsOneWidget);
    expect(_navBar(tester).selectedIndex, 0);
  });

  testWidgets('tapping each destination shows the right screen', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Trilha'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillTreePlaceholderScreen), findsOneWidget);
    expect(_navBar(tester).selectedIndex, 1);

    await tester.tap(find.text('Progresso'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressPlaceholderScreen), findsOneWidget);
    expect(_navBar(tester).selectedIndex, 2);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Seguir o sistema'), findsOneWidget);
    expect(_navBar(tester).selectedIndex, 3);
  });

  testWidgets('no swipe navigation (no PageView)', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(IndexedStack), findsOneWidget);
  });

  testWidgets('Android back on a non-Home tab returns to Home', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(_navBar(tester).selectedIndex, 3);

    final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
    expect((tester.widget(popScopeFinder) as PopScope).canPop, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_navBar(tester).selectedIndex, 0);

    // On the Home tab the shell now lets the pop through.
    expect((tester.widget(popScopeFinder) as PopScope).canPop, isTrue);
  });
}
