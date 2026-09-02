// Enforces CatEar's module boundaries (AD-1) in CI, without a custom_lint
// plugin. For every Dart library under lib/, it resolves every import and
// export target (relative paths normalised to a lib-relative path) and checks:
//
//  1. A file NOT under lib/<m>/ must not reference lib/<m>/data/** or
//     lib/<m>/presentation/** — features are reached only through their
//     public barrel lib/<m>/<m>.dart.
//  2. A file NOT under lib/core/ must not import Drift internals directly:
//     no `*.drift.dart` target and no lib/core/database/** target except the
//     `lib/core/core.dart` barrel. This keeps Drift-generated symbols inside
//     core/ (they never cross data/ -> domain/).
//  3. lib/ must contain at least one .dart file and every one must parse.
//  4. Only files under lib/audio/ may import/export `just_audio` / `record`
//     or any of their sibling packages (`just_audio_background`,
//     `record_platform_interface`, …) — the platform audio packages stay
//     behind the AudioService interface (AR-6). Checked on the raw import URI,
//     before target resolution (which returns null for external packages).
//  5. No file under lib/ may import/export a module's test-only surface
//     (lib/<m>/testing.dart or lib/<m>/testing/**) — the fakes/spies there are
//     reachable only from test/. Production code depends on the interface plus
//     its provider, never on a test double.
//
// Exit code is non-zero on any violation, naming the offending file and line.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

const _modules = [
  'core',
  'nivelamento',
  'exercicios',
  'progressao',
  'audio',
  'curriculo',
];

void main(List<String> args) {
  final root = args.isNotEmpty ? args.first : Directory.current.path;
  final libDir = Directory(p.join(root, 'lib'));
  if (!libDir.existsSync()) {
    stderr.writeln('check_module_boundaries: no lib/ directory at $root');
    exit(2);
  }

  final dartFiles =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .where((f) => !f.path.endsWith('.drift.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (dartFiles.isEmpty) {
    stderr.writeln('check_module_boundaries: lib/ has no .dart files');
    exit(1);
  }

  final violations = <String>[];

  for (final file in dartFiles) {
    final libRelative = p.posix.normalize(
      p.relative(file.path, from: libDir.path).replaceAll(r'\', '/'),
    );

    final parsed = parseString(
      content: file.readAsStringSync(),
      path: file.path,
      throwIfDiagnostics: false,
    );
    final syntaxErrors = parsed.errors
        .where((e) => e.diagnosticCode.type.name == 'SYNTACTIC_ERROR')
        .toList();
    if (syntaxErrors.isNotEmpty) {
      for (final err in syntaxErrors) {
        final line = parsed.lineInfo.getLocation(err.offset).lineNumber;
        violations.add('$libRelative:$line: parse error: ${err.message}');
      }
      continue;
    }

    final owningModule = _moduleOf(libRelative);

    for (final directive in parsed.unit.directives) {
      String? uri;
      if (directive is ImportDirective) {
        uri = directive.uri.stringValue;
      } else if (directive is ExportDirective) {
        uri = directive.uri.stringValue;
      } else {
        continue;
      }
      if (uri == null) continue;

      final line = parsed.lineInfo.getLocation(directive.offset).lineNumber;

      // Rule 4: platform audio packages stay under lib/audio/ (AR-6). Checked
      // on the raw uri — _resolveTarget returns null for external packages.
      // Matches `just_audio` / `record` and their sibling packages
      // (`just_audio_background`, `record_platform_interface`, …) but not an
      // unrelated name that merely starts with the same letters (`recorder`).
      final pkgName = RegExp(r'^package:([^/]+)/').firstMatch(uri)?.group(1);
      final referencesPlatformAudio =
          pkgName != null &&
          (pkgName == 'just_audio' ||
              pkgName == 'record' ||
              pkgName.startsWith('just_audio_') ||
              pkgName.startsWith('record_'));
      if (referencesPlatformAudio && owningModule != 'audio') {
        violations.add(
          '$libRelative:$line: imports/exports platform audio package '
          '("$uri") from outside lib/audio/',
        );
      }

      final target = _resolveTarget(uri, libRelative);
      if (target == null) continue; // dart:, package: (other), sdk imports

      // Rule 2: Drift internals stay in core/.
      final referencesDrift =
          target.endsWith('.drift.dart') ||
          (target.startsWith('core/database/') && target != 'core/core.dart');
      if (referencesDrift && owningModule != 'core') {
        violations.add(
          '$libRelative:$line: references core database internals '
          '("$uri") from outside lib/core/',
        );
      }

      // Rule 1: no cross-module data/ or presentation/ reach-in.
      final targetModule = _moduleOf(target);
      if (targetModule == null) continue;

      // Rule 5: test-only surface (lib/<m>/testing.dart, lib/<m>/testing/**)
      // is reachable only from test/ — never from another lib/ file. The
      // testing barrel re-exporting its own testing/ dir is the one allowed
      // reference.
      final fromTestingSurface =
          owningModule != null &&
          (libRelative == '$owningModule/testing.dart' ||
              libRelative.startsWith('$owningModule/testing/'));
      final referencesTestingSurface =
          !fromTestingSurface &&
          (target == '$targetModule/testing.dart' ||
              target.startsWith('$targetModule/testing/'));
      if (referencesTestingSurface) {
        violations.add(
          '$libRelative:$line: imports test-only surface "$uri" '
          '(lib/$targetModule/testing…) from lib/ — test doubles belong to '
          'test/ only',
        );
      }

      final isPrivateLayer =
          target.startsWith('$targetModule/data/') ||
          target.startsWith('$targetModule/presentation/');
      if (isPrivateLayer && owningModule != targetModule) {
        violations.add(
          '$libRelative:$line: imports module-private '
          '"$uri" (lib/$targetModule/${target.startsWith('$targetModule/data/') ? 'data' : 'presentation'}/) '
          'from outside lib/$targetModule/',
        );
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Module boundary violations:');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'check_module_boundaries: OK (${dartFiles.length} files, '
    '${_modules.length} modules)',
  );
}

String? _moduleOf(String libRelativePath) {
  final first = libRelativePath.split('/').first;
  return _modules.contains(first) ? first : null;
}

/// Normalises an import/export URI to a lib-relative posix path, or null when
/// it is not a file inside this package's lib/.
String? _resolveTarget(String uri, String fromLibRelative) {
  if (uri.startsWith('package:catear/')) {
    return p.posix.normalize(uri.substring('package:catear/'.length));
  }
  if (uri.startsWith('package:') ||
      uri.startsWith('dart:') ||
      uri.contains(':')) {
    return null;
  }
  // Relative import — resolve against the importing file's directory.
  final fromDir = p.posix.dirname(fromLibRelative);
  return p.posix.normalize(p.posix.join(fromDir, uri));
}
