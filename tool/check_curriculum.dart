// Build gate for the curriculum catalog (AR-8). Mirrors the style of
// tool/check_module_boundaries.dart: reads the JSON as a plain file, prints
// every violation, exits non-zero on any.
//
// It runs the SHARED structural validation (lib/curriculo/domain/
// curriculum_validation.dart — the same rules CurriculoRepository.load()
// enforces at runtime) PLUS the content invariants R1/R2/R3
// (checkFadingAndOrder), which are the build gate's alone.
//
// Exit codes: 0 = OK, 1 = violations / unreadable JSON, 2 = file not found.
//
// Usage: dart run tool/check_curriculum.dart [path-to-catalog.json]
//        (defaults to assets/curriculum/catalog_v1.json under the repo root)

import 'dart:convert';
import 'dart:io';

import 'package:catear/curriculo/domain/curriculum_validation.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final path = args.isNotEmpty
      ? args.first
      : p.join(Directory.current.path, 'assets/curriculum/catalog_v1.json');

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('check_curriculum: catalog not found at $path');
    exit(2);
  }

  Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('check_curriculum: <root>: unreadable JSON: ${e.message}');
    exit(1);
  }

  final violations = <CurriculumViolation>[
    ...validateCatalogStructure(decoded),
    ...checkFadingAndOrder(decoded),
  ];

  if (violations.isNotEmpty) {
    stderr.writeln('Curriculum violations ($path):');
    for (final v in violations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln('check_curriculum: OK ($path)');
}
