// Verifies the app id `app.catear` and display name `CatEar` on both platforms
// (AR-12).
// Android: applicationId in android/app/build.gradle(.kts);
//          android:label in android/app/src/main/AndroidManifest.xml
// iOS: PRODUCT_BUNDLE_IDENTIFIER + CFBundleDisplayName in the Xcode project /
//      ios/Runner/Info.plist
//
// Exit non-zero if any is missing.

import 'dart:io';

const _expected = 'app.catear';
const _displayName = 'CatEar';

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

  final manifest = File('$root/android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    problems.add('android: ${manifest.path} not found');
  } else if (!manifest.readAsStringSync().contains(
    'android:label="$_displayName"',
  )) {
    problems.add(
      'android: android:label="$_displayName" not found in ${manifest.path}',
    );
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

  final infoPlist = File('$root/ios/Runner/Info.plist');
  if (!infoPlist.existsSync()) {
    problems.add('ios: ${infoPlist.path} not found');
  } else {
    final text = infoPlist.readAsStringSync();
    final ok = RegExp(
      '<key>CFBundleDisplayName</key>\\s*<string>'
      '${RegExp.escape(_displayName)}</string>',
    ).hasMatch(text);
    if (!ok) {
      problems.add(
        'ios: CFBundleDisplayName "$_displayName" not found in '
        '${infoPlist.path}',
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
  stdout.writeln(
    'check_app_id: OK ($_expected + "$_displayName" on android + ios)',
  );
}
