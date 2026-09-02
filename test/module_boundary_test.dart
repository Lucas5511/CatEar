import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Exercises `tool/check_module_boundaries.dart` against synthetic lib/ trees —
/// a passing case and a failing case per rule.
void main() {
  final projectRoot = Directory.current.path;
  final script = p.join(projectRoot, 'tool', 'check_module_boundaries.dart');

  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('catear_boundary_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  void write(String relative, String content) {
    final f = File(p.join(tmp.path, relative));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  Future<ProcessResult> run() => Process.run('dart', ['run', script, tmp.path]);

  test('clean tree passes', () async {
    write('lib/core/core.dart', "library;\nexport 'theme.dart';\n");
    write('lib/core/theme.dart', 'const answer = 42;\n');
    write(
      'lib/app/main_screen.dart',
      "import 'package:catear/progressao/progressao.dart';\nvoid f() {}\n",
    );
    write(
      'lib/progressao/progressao.dart',
      "library;\nexport 'presentation/screen.dart';\n",
    );
    write('lib/progressao/presentation/screen.dart', 'class S {}\n');

    final r = await run();
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test(
    'outside file importing another module data/ fails (package: uri)',
    () async {
      write('lib/core/core.dart', 'library;\n');
      write(
        'lib/app/leak.dart',
        "import 'package:catear/exercicios/data/secret.dart';\nvoid f() {}\n",
      );
      write('lib/exercicios/data/secret.dart', 'class Secret {}\n');

      final r = await run();
      expect(r.exitCode, isNot(0));
      expect(r.stderr.toString(), contains('app/leak.dart'));
    },
  );

  test('outside file re-exporting another module presentation/ fails '
      '(relative uri)', () async {
    write('lib/core/core.dart', 'library;\n');
    write(
      'lib/app/reexport.dart',
      "export '../nivelamento/presentation/hidden.dart';\n",
    );
    write('lib/nivelamento/presentation/hidden.dart', 'class H {}\n');

    final r = await run();
    expect(r.exitCode, isNot(0));
    expect(r.stderr.toString(), contains('reexport.dart'));
  });

  test('non-core file importing core database internals fails', () async {
    write('lib/core/core.dart', 'library;\n');
    write(
      'lib/progressao/data/repo.dart',
      "import 'package:catear/core/database/app_database.dart';\n",
    );

    final r = await run();
    expect(r.exitCode, isNot(0));
    expect(r.stderr.toString(), contains('database internals'));
  });

  test('just_audio / record imports inside lib/audio/ pass (Rule 4)', () async {
    write('lib/core/core.dart', 'library;\n');
    write(
      'lib/audio/data/audio_service_impl.dart',
      "import 'package:just_audio/just_audio.dart';\nvoid f() {}\n",
    );
    write(
      'lib/audio/data/voice_capture.dart',
      "import 'package:record/record.dart';\nvoid g() {}\n",
    );

    final r = await run();
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test('just_audio import outside lib/audio/ fails (Rule 4)', () async {
    write('lib/core/core.dart', 'library;\n');
    write(
      'lib/exercicios/data/player.dart',
      "import 'package:just_audio/just_audio.dart';\nvoid f() {}\n",
    );

    final r = await run();
    expect(r.exitCode, isNot(0));
    expect(r.stderr.toString(), contains('exercicios/data/player.dart'));
    expect(r.stderr.toString(), contains('platform audio package'));
  });

  test('sibling package (just_audio_background) outside lib/audio/ fails '
      '(Rule 4)', () async {
    write('lib/core/core.dart', 'library;\n');
    write(
      'lib/progressao/data/bg.dart',
      "import 'package:just_audio_background/just_audio_background.dart';\n"
          'void f() {}\n',
    );

    final r = await run();
    expect(r.exitCode, isNot(0));
    expect(r.stderr.toString(), contains('progressao/data/bg.dart'));
    expect(r.stderr.toString(), contains('platform audio package'));
  });

  test('record export outside lib/audio/ fails (Rule 4)', () async {
    write('lib/core/core.dart', 'library;\n');
    write(
      'lib/nivelamento/data/capture.dart',
      "export 'package:record/record.dart';\n",
    );

    final r = await run();
    expect(r.exitCode, isNot(0));
    expect(r.stderr.toString(), contains('nivelamento/data/capture.dart'));
    expect(r.stderr.toString(), contains('platform audio package'));
  });

  test('empty lib/ fails', () async {
    write('lib/.gitkeep', '');
    final r = await run();
    expect(r.exitCode, isNot(0));
  });

  test('unparseable dart fails', () async {
    write('lib/core/core.dart', 'library;\n');
    write('lib/app/broken.dart', 'void f( {\n');
    final r = await run();
    expect(r.exitCode, isNot(0));
    expect(r.stderr.toString(), contains('broken.dart'));
  });
}
