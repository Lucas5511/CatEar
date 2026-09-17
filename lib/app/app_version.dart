import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What Settings → "Sobre" shows when the version cannot be read.
const String unknownAppVersion = '—';

/// The running build's version, formatted as `1.0.0 (1)` — `version (build)`
/// from `pubspec.yaml`, read from the installed package at runtime.
///
/// The single point of use of `package_info_plus` in the app. It is read rather
/// than hard-coded because the constant it replaces (`'1.0.0'` in
/// `settings_screen.dart`) started lying the moment `pubspec.yaml` was bumped,
/// and a version string that lies is worse than none.
///
/// Never fails: a platform channel that is missing (a widget test, an unusual
/// host) resolves to [unknownAppVersion] and is logged, so the Settings screen
/// renders either way.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    // A lookup that succeeds but hands back nothing is the same fact as one
    // that failed: the version is unknown. Without this the row would read
    // " (1)", or be blank, which claims more than it knows.
    if (info.version.isEmpty) {
      developer.log(
        'The package reported an empty version',
        name: 'catear.app',
      );
      return unknownAppVersion;
    }
    final build = info.buildNumber;
    return build.isEmpty ? info.version : '${info.version} ($build)';
  } catch (error, stack) {
    developer.log(
      'Failed to read the package version',
      name: 'catear.app',
      error: error,
      stackTrace: stack,
    );
    return unknownAppVersion;
  }
});
