import 'package:catear/app/app_version.dart';
import 'package:catear/app/settings_screen.dart';
import 'package:catear/core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Story 1.10 — the Settings screen itself.
///
/// The theme rows are driven against a real in-memory Drift database through
/// the real `ThemePreferenceRepository`: the thing worth proving is that a tap
/// reaches the `preferences` table and that a stored value comes back on the
/// next read, not that a fake was called.
void main() {
  setUpAll(() {
    // One lookup for the whole file: `PackageInfo` caches the first successful
    // one anyway. The version *value* is covered by app_version_test.dart;
    // here it only has to be present.
    PackageInfo.setMockInitialValues(
      appName: 'CatEar',
      packageName: 'app.catear',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  AppDatabase newDatabase() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  Future<void> pumpSettings(
    WidgetTester tester, {
    AppDatabase? database,
    List<Override> overrides = const [],
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    final db = database ?? newDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async => db),
          ...overrides,
        ],
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(textScaler: textScaler),
            child: const Scaffold(body: SettingsScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // --- Tema: applied now, remembered later -----------------------------------

  testWidgets('picking "Escuro" writes the choice to the preferences table', (
    tester,
  ) async {
    final db = newDatabase();
    await pumpSettings(tester, database: db);

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(await db.preferencesDao.get(_themeModeKey), 'dark');
  });

  testWidgets('a stored choice comes back selected on the next read', (
    tester,
  ) async {
    final db = newDatabase();
    await db.preferencesDao.put(_themeModeKey, 'dark');

    await pumpSettings(tester, database: db);

    expect(_selectedMode(tester), ThemeMode.dark);
  });

  testWidgets('no stored choice -> "Seguir o sistema"', (tester) async {
    await pumpSettings(tester);

    expect(_selectedMode(tester), ThemeMode.system);
  });

  testWidgets('an unreadable stored value falls back to "Seguir o sistema"', (
    tester,
  ) async {
    final db = newDatabase();
    // What a downgrade or a hand-edited database would leave behind.
    await db.preferencesDao.put(_themeModeKey, 'solarized');

    await pumpSettings(tester, database: db);

    expect(_selectedMode(tester), ThemeMode.system);
  });

  testWidgets('a failed write still applies the choice — the tap is never '
      'refused because the database is', (tester) async {
    await pumpSettings(
      tester,
      overrides: [
        themePreferenceRepositoryProvider.overrideWithValue(
          _FailingThemePreferenceRepository(),
        ),
      ],
    );

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(_selectedMode(tester), ThemeMode.dark);
  });

  // --- Microfone: present, inert ---------------------------------------------

  testWidgets('the microphone row is disabled, explained, and inert', (
    tester,
  ) async {
    await pumpSettings(tester);

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Microfone'),
    );
    expect(tile.enabled, isFalse);
    expect(tile.onTap, isNull, reason: 'nothing happens when it is tapped');
    expect(find.text('Chega com a produção vocal'), findsOneWidget);

    // Epic 1 asks for no permission and offers no way out to the OS settings.
    expect(find.textContaining('Permitir'), findsNothing);
    expect(find.textContaining('Configurações do sistema'), findsNothing);
  });

  testWidgets('a screen reader hears the microphone row as disabled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSettings(tester);

    // "has an enabled state, and it is off" is exactly what a screen reader
    // reads out as unavailable — a subtitle alone would not.
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Microfone'),
          matching: find.text('Microfone'),
        ),
      ),
      isSemantics(hasEnabledState: true, isEnabled: false),
    );

    handle.dispose();
  });

  testWidgets('each theme row announces its role and its checked state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final db = newDatabase();
    await db.preferencesDao.put(_themeModeKey, 'dark');
    await pumpSettings(tester, database: db);

    for (final (label, checked) in [
      ('Claro', false),
      ('Escuro', true),
      ('Seguir o sistema', false),
    ]) {
      expect(
        tester.getSemantics(find.text(label)),
        isSemantics(
          label: label,
          // Role…
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          // …and state.
          isChecked: checked,
          isEnabled: true,
          hasEnabledState: true,
        ),
        reason:
            '"$label" must announce its role and whether it is the '
            'current choice',
      );
    }

    handle.dispose();
  });

  // --- Sobre ------------------------------------------------------------------

  testWidgets('"Sobre" shows the build version, not a constant', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('Versão'), findsOneWidget);
    expect(find.text('1.0.0 (1)'), findsOneWidget);
  });

  testWidgets('a version that cannot be read shows "—" and nothing breaks', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      overrides: [
        appVersionProvider.overrideWith(
          (ref) => Future<String>.error(StateError('no platform channel')),
        ),
      ],
    );

    expect(find.text('Versão'), findsOneWidget);
    expect(find.text(unknownAppVersion), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  // --- A11y -------------------------------------------------------------------

  testWidgets('no overflow at TextScaler.linear(2.0)', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    await pumpSettings(tester, textScaler: const TextScaler.linear(2.0));
    // Scroll the whole list so every row is actually laid out.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(errors.map((e) => e.toString()), isEmpty);
  });

  testWidgets('every row is at least 48 dp tall, at both text scales', (
    tester,
  ) async {
    // Tall enough for the whole list at 2.0, so every row is really built:
    // on the default 800x600 surface the `ListView` stops building after the
    // ones that fit and this would silently measure a subset.
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final scaler in [TextScaler.noScaling, const TextScaler.linear(2.0)]) {
      await pumpSettings(tester, textScaler: scaler);

      final rows = find.byType(ListTile);
      expect(rows, findsNWidgets(5)); // 3 radios + microphone + version
      for (var i = 0; i < 5; i++) {
        expect(
          tester.getSize(rows.at(i)).height,
          greaterThanOrEqualTo(48.0),
          reason: 'row $i at $scaler',
        );
      }
    }
  });
}

/// The `preferences` key the theme repository owns. A local copy: the key is
/// `core/`'s business, not part of its public surface, and the round-trip tests
/// in `test/core/theme_preference_test.dart` are what prove it is this one.
const String _themeModeKey = 'theme_mode';

/// The mode the radio group currently shows as chosen.
ThemeMode _selectedMode(WidgetTester tester) => tester
    .widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>))
    .groupValue!;

/// A repository whose writes always fail — a full disk, a revoked file.
class _FailingThemePreferenceRepository implements ThemePreferenceRepository {
  @override
  Future<ThemeMode?> read() async => null;

  @override
  Future<void> write(ThemeMode mode) async =>
      throw StateError('simulated write failure');
}
