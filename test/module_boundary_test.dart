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
