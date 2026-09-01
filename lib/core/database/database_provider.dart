import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Opens the [AppDatabase] at `<application support dir>/catear.sqlite`.
///
/// Any failure resolving the path or opening the file surfaces as an
/// [AsyncError] on this provider; the UI shows `DatabaseErrorScreen` with a
/// retry that invalidates this provider.
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final AppDatabase db;
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'catear.sqlite'));
    db = AppDatabase(NativeDatabase.createInBackground(file));
    // Force the connection open now so errors surface here, not later.
    await db.customSelect('SELECT 1').get();
  } catch (error, stack) {
    developer.log(
      'Failed to open the CatEar database',
      name: 'catear.database',
      error: error,
      stackTrace: stack,
    );
    rethrow;
  }

  ref.onDispose(db.close);
  return db;
});
