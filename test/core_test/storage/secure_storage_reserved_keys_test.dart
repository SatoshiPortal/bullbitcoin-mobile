import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

/// The app and the `secrets` package share one OS keystore. This is the fence: the app's own store refuses every key the package owns, so a preference read can never come back holding seed or database-key material.
void main() {
  late SecureStorageDatasourceImpl store;

  setUp(() {
    FakeSecureStoragePlatform().install();
    store = SecureStorageDatasourceImpl(const FlutterSecureStorage());
  });

  for (final key in [
    'seed_73c5da0a',
    'com.bullbitcoin.secrets/dek/swaps/main',
  ]) {
    test('$key is refused on every operation', () {
      // Synchronously, before any keystore call: the key never reaches the
      // plugin at all.
      expect(() => store.getValue(key), throwsArgumentError);
      expect(() => store.saveValue(key: key, value: 'x'), throwsArgumentError);
      expect(() => store.deleteValue(key), throwsArgumentError);
      expect(() => store.hasValue(key), throwsArgumentError);
    });
  }

  test('a listing hides them rather than handing them over', () async {
    final storage = FakeSecureStoragePlatform(
      entries: {
        'seed_73c5da0a': 'a seed',
        'com.bullbitcoin.secrets/dek/swaps/main': 'a database key',
        'settings_environment': 'mainnet',
      },
    )..install();
    store = SecureStorageDatasourceImpl(const FlutterSecureStorage());

    expect(await store.getAll(), {'settings_environment': 'mainnet'});
    expect(storage.entries, hasLength(3), reason: 'hidden, not deleted');
  });

  test('the refusal is written against the package own prefixes', () {
    // Not a second list to keep in step: if the package adds a namespace,
    // this is what makes the app refuse it too.
    expect(Secrets.reservedKeyPrefixes, {'seed_', 'com.bullbitcoin.secrets'});
  });
}
