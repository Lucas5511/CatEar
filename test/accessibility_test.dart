import 'package:catear/app/database_error_screen.dart';
import 'package:catear/app/home_shell.dart';
import 'package:catear/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('no overflow at TextScaler.linear(2.0)', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: HomeShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Visit every tab so all placeholder screens get laid out.
    for (final label in ['Trilha', 'Progresso', 'Ajustes', 'Home']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    final overflow = errors
        .where((e) => e.exceptionAsString().contains('overflowed'))
        .toList();
    expect(overflow, isEmpty, reason: overflow.map((e) => e.toString()).join());

    // Don't silently swallow other exceptions raised during the pumps.
    final other = errors
        .where((e) => !e.exceptionAsString().contains('overflowed'))
        .toList();
    expect(other, isEmpty, reason: other.map((e) => e.toString()).join());
  });

  testWidgets(
    'DatabaseErrorScreen does not overflow at TextScaler.linear(2.0)',
    (tester) async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: DatabaseErrorScreen(onRetry: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(errors.map((e) => e.toString()), isEmpty);
    },
  );

  testWidgets('NavigationBar touch targets are >= 48dp tall', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final barSize = tester.getSize(find.byType(NavigationBar));
    expect(barSize.height, greaterThanOrEqualTo(48.0));

    // Every destination's tappable area is at least 48dp in both axes.
    final targets = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(GestureDetector),
    );
    expect(targets, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      final size = tester.getSize(targets.at(i));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }
  });
}
