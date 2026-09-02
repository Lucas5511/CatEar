import 'dart:async';

import 'package:drift/drift.dart';

/// Auto-loaded by `flutter test` for everything under `test/`.
///
/// Many suites construct a fresh in-memory [AppDatabase] per test (each closed
/// via `addTearDown`). Drift's debug-only heuristic counts constructions and
/// dumps a full stack trace warning about "multiple databases" — noise, not a
/// leak. Silence it so failing tests stay easy to spot in the log.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
