// Verifies the app id is `app.catear` on both platforms (AR-12).
// Android: applicationId in android/app/build.gradle(.kts)
// iOS: PRODUCT_BUNDLE_IDENTIFIER in ios/Runner.xcodeproj/project.pbxproj
//
// Exit non-zero if the id is missing on either platform.

import 'dart:io';

const _expected = 'app.catear';

void main(List<String> args) {
  final root = args.isNotEmpty ? args.first : Directory.current.path;
  final problems = <String>[];

  final gradleCandidates = [
    File('$root/android/app/build.gradle.kts'),
    File('$root/android/app/build.gradle'),
  ];
  final gradle = gradleCandidates.firstWhere(
    (f) => f.existsSync(),
    orElse: () => gradleCandidates.first,
  );
  if (!gradle.existsSync()) {
    problems.add('android: no build.gradle(.kts) found');
  } else {
    final text = gradle.readAsStringSync();
    final ok = RegExp('applicationId\\s*=?\\s*"${RegExp.escape(_expected)}"')
        .hasMatch(text);
    if (!ok) {
      problems.add(
        'android: applicationId "$_expected" not found in '
        '${gradle.path}',
      );
    }
  }

  final pbxproj = File('$root/ios/Runner.xcodeproj/project.pbxproj');
  if (!pbxproj.existsSync()) {
    problems.add('ios: ${pbxproj.path} not found');
  } else {
    final text = pbxproj.readAsStringSync();
    final ok = text.contains('PRODUCT_BUNDLE_IDENTIFIER = $_expected;');
    if (!ok) {
      problems.add(
        'ios: PRODUCT_BUNDLE_IDENTIFIER "$_expected" not found in '
        '${pbxproj.path}',
      );
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln('check_app_id: FAILED');
    for (final p in problems) {
      stderr.writeln('  $p');
    }
    exit(1);
  }
  stdout.writeln('check_app_id: OK ($_expected on android + ios)');
}
