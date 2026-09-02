import 'dart:async';

import 'package:drift/drift.dart';

/// Auto-loaded by `flutter test integration_test`.
///
/// The E2E suite builds a fresh in-memory [AppDatabase] per test via `pumpApp`
/// (each closed in `addTearDown`). Drift's debug-only "multiple databases"
/// heuristic then dumps a stack-trace warning — noise, not a leak. Silence it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
