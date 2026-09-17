import 'package:catear/app/app_version.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Story 1.10 — "Sobre → Versão" when the platform cannot answer.
///
/// A FILE OF ITS OWN ON PURPOSE. `PackageInfo` caches the first successful
/// lookup in a static field with no public reset, so a mocked case anywhere in
/// the same file would make this one take the cached path instead of the
/// failing one — and it would still pass, proving nothing. Each test file is a
/// separate isolate, which is the only reset there is; a comment about
/// declaration order was not, since a randomised order would have defeated it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a platform lookup that fails degrades to "—", it does not throw', () async {
    // No mock, no plugin registered: `PackageInfo.fromPlatform()` fails the way
    // it would on a host where the platform channel is missing.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(appVersionProvider.future), unknownAppVersion);
  });
}
