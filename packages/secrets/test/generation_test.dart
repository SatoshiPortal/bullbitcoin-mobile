import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// `Secrets.generate` is where every new wallet's seed comes into being, and
/// until now nothing exercised it: the package's own comments held that bdk
/// could not load under `flutter test`. It can — bdk ships as a native asset
/// — so the birth of a seed is pinned here, through the public API.
void main() {
  Secrets secretsWith(FakeSecureStoragePlatform storage) {
    storage.install();
    return Secrets(scratchDirectory: () async => '/tmp');
  }

  test(
    'generates twelve words by default, stores them, hands back a handle',
    () async {
      final storage = FakeSecureStoragePlatform();
      final secret = ok(await secretsWith(storage).generate());

      expect(secret.info.isMnemonic, isTrue);
      expect(secret.info.wordCount, 12);
      expect(secret.info.hasPassphrase, isFalse);
      expect(storage.entries.keys, ['seed_${secret.id.hex}']);
    },
  );

  test('every word count the type allows is honoured', () async {
    for (final count in MnemonicWordCount.values) {
      final secret = ok(
        await secretsWith(
          FakeSecureStoragePlatform(),
        ).generate(wordCount: count),
      );
      expect(secret.info.wordCount, count.count, reason: count.name);
    }
  });

  test('two generations never share an identity', () async {
    final secrets = secretsWith(FakeSecureStoragePlatform());
    final a = ok(await secrets.generate());
    final b = ok(await secrets.generate());
    expect(a.id, isNot(b.id));
  });
}
