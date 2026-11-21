import 'dart:io';

import 'package:bb_mobile/features/swap/data/secure_secret_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSecureStoragePlatform storage;
  late SecureSecretStore store;
  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    store = SecureSecretStore(
      Secrets(scratchDirectory: () async => Directory.systemTemp.path)
          .swapKeychain,
    );
  });
  test('the engine reaches exactly its own legacy entries', () async {
    storage.entries['swap_master_key_mainnet_f00dbabe'] = 'value';
    expect(await store.read('swap_master_key_mainnet_f00dbabe'), 'value');
    await store.write('swap_regtest_abc', 'blob');
    expect(storage.entries['swap_regtest_abc'], 'blob');
    await store.delete('swap_regtest_abc');
    expect(storage.entries.containsKey('swap_regtest_abc'), false);
  });
  test('foreign entries are refused before storage access', () async {
    for (final key in [
      'securityKey',
      'seed_f00dbabe',
      'exchange_api_key',
      'com.bullbitcoin.secrets/dek/swaps/main',
    ]) {
      await expectLater(store.read(key), throwsArgumentError);
      await expectLater(store.write(key, 'x'), throwsArgumentError);
      await expectLater(store.delete(key), throwsArgumentError);
    }
    expect(storage.reads, 0);
    expect(storage.entries, isEmpty);
  });
  test(
    'locked reads and failed writes propagate through the engine port',
    () async {
      storage.locked = true;
      await expectLater(store.read('swap_abc'), throwsException);
      storage.writesFail = true;
      await expectLater(store.write('swap_abc', 'x'), throwsException);
      await expectLater(store.delete('swap_abc'), throwsException);
      expect(storage.entries, isEmpty);
    },
  );
}
