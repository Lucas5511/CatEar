import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/curriculum_fixtures.dart';

/// Subprocess smoke tests for `tool/check_curriculum.dart` — just the exit-code
/// contract. The rule coverage (structural + R1/R2/R3) lives in
/// `test/curriculum_validation_test.dart`, testing the shared functions
/// directly.
void main() {
  final root = Directory.current.path;
  final script = p.join(root, 'tool', 'check_curriculum.dart');

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('catear_curriculum_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<ProcessResult> runOn(String contents) {
    final f = File(p.join(tmp.path, 'catalog.json'))
      ..writeAsStringSync(contents);
    return Process.run('dart', ['run', script, f.path]);
  }

  test('committed catalog_v1.json -> exit 0', () async {
    final r = await Process.run('dart', ['run', script]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test(
    'good fixture: reversed stages array + scaffoldIntensity hole -> exit 0',
    () async {
      final r = await runOn(
        catalogFixtureString(
          (j) => j['stages'] = stagesOf(j).reversed.toList(),
        ),
      );
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    },
  );

  test('structural violation -> exit 1, names the target', () async {
    final r = await runOn(catalogFixtureString((j) => j['schemaVersion'] = 2));
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains('schemaVersion'));
  });

  test('R2 violation -> exit 1', () async {
    final r = await runOn(
      catalogFixtureString(
        (j) => stageById(j, 's-tritono')['scaffoldIntensity'] = 1.0,
      ),
    );
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains('R2'));
  });

  test('unreadable JSON -> exit 1', () async {
    final r = await runOn('{ not json');
    expect(r.exitCode, 1);
  });

  test('missing catalog file -> exit 2', () async {
    final r = await Process.run('dart', [
      'run',
      script,
      p.join(tmp.path, 'does_not_exist.json'),
    ]);
    expect(r.exitCode, 2);
  });
}
