import 'dart:io';

import 'package:catear/app/app_version.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Story 1.10 — the "Sobre → Versão" value, read from the build.
///
/// The failure case (no platform channel at all) lives in
/// `app_version_missing_platform_test.dart`: `PackageInfo` caches the first
/// successful lookup in a static with no public reset, so it cannot share a
/// file with the mocked cases below.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Installs [version] / [build] as what the platform reports, and resolves
  /// the provider against it. `setMockInitialValues` overwrites the cached
  /// value, so successive cases in this file are independent.
  Future<String> versionFor(String version, String build) {
    PackageInfo.setMockInitialValues(
      appName: 'CatEar',
      packageName: 'app.catear',
      version: version,
      buildNumber: build,
      buildSignature: '',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(appVersionProvider.future);
  }

  test('the version shown is the pubspec\'s version+build, formatted '
      '"version (build)"', () async {
    // Read from pubspec.yaml rather than hard-coded here: the point of the
    // story is that no constant in the tree claims to be the version. Bumping
    // `version:` must move this test's expectation with it, not break it.
    final (version, build) = _pubspecVersion();

    expect(await versionFor(version, build), '$version ($build)');
  });

  test('a build number the platform leaves empty is simply left out', () async {
    expect(await versionFor('2.1.0', ''), '2.1.0');
  });

  test('a lookup that succeeds with an empty version is still "—"', () async {
    // Succeeding with nothing to say is the same fact as failing: without the
    // guard this row would read " (7)".
    expect(await versionFor('', '7'), unknownAppVersion);
    expect(await versionFor('', ''), unknownAppVersion);
  });
}

/// `version: X+Y` from pubspec.yaml, as (X, Y).
(String, String) _pubspecVersion() {
  final line = File('pubspec.yaml').readAsLinesSync().firstWhere(
    (l) => l.startsWith('version:'),
    orElse: () => fail('no version: line in pubspec.yaml'),
  );
  final value = line.substring('version:'.length).trim();
  final parts = value.split('+');
  expect(parts, hasLength(2), reason: 'pubspec version must be "X+Y": $value');
  return (parts[0], parts[1]);
}
