import 'package:catear/app/home_shell.dart';
import 'package:catear/core/core.dart';
import 'package:catear/progressao/progressao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app() => ProviderScope(
  child: MaterialApp(
    theme: appTheme(Brightness.light),
    home: const HomeShell(),
  ),
);

NavigationBar _navBar(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

void main() {
  testWidgets('starts on the Home tab', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('Bem-vinda ao CatEar!'), findsOneWidget);
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
