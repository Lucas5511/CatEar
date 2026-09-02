import 'package:catear/app/home_shell.dart';
import 'package:catear/audio/audio.dart';
import 'package:catear/audio/testing.dart';
import 'package:catear/core/core.dart';
import 'package:catear/exercicios/exercicios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('"Praticar" on Home pushes the exercise screen; back returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioServiceProvider.overrideWithValue(FakeAudioService())],
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Praticar'), findsOneWidget);
    await tester.tap(find.text('Praticar'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(IntervalExerciseScreen), findsOneWidget);

    // Android back returns to Home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(IntervalExerciseScreen), findsNothing);
    expect(find.text('Que bom ter você no CatEar!'), findsOneWidget);
  });
}
