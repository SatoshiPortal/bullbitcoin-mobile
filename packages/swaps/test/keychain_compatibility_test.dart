import 'dart:io';

import 'package:swaps/swaps.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Rows extends Mock implements SwapRowStore {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSecureStoragePlatform storage;
  late SwapStorage store;
  late SwapKeychain keychain;
  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    keychain = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => Directory.systemTemp.path,
    ).swapKeychain;
    store = SwapStorage(rows: _Rows(), secrets: keychain);
  });
  test('the engine reaches exactly its own legacy entries', () async {
    storage.entries['swap_master_key_index_f00dbabe'] = '7';
    expect(await store.getSwapKeyIndex('f00dbabe'), 7);
    await store.setSwapKeyIndex('f00dbabe', 8);
    expect(storage.entries['swap_master_key_index_f00dbabe'], '8');
    storage.entries['swap_regtest_abc'] = 'blob';
    final regtest = store.regtestView(rows: _Rows());
    await regtest.deleteFromSecureStorage('abc');
    expect(storage.entries.containsKey('swap_regtest_abc'), false);
    expect(storage.entries['swap_master_key_index_f00dbabe'], '8');
  });
  test('foreign entries are refused before storage access', () async {
    for (final key in [
      'securityKey',
      'seed_f00dbabe',
      'exchange_api_key',
      'com.bullbitcoin.secrets/dek/swaps/main',
    ]) {
      expect(() => keychain.read(key), throwsArgumentError);
      expect(() => keychain.write(key, 'x'), throwsArgumentError);
      expect(() => keychain.delete(key), throwsArgumentError);
    }
    expect(storage.reads, 0);
    expect(storage.entries, isEmpty);
  });
  test(
    'locked reads and failed writes propagate through the engine port',
    () async {
      storage.locked = true;
      await expectLater(store.getSwapKeyIndex('abc'), throwsException);
      storage.writesFail = true;
      await expectLater(store.setSwapKeyIndex('abc', 1), throwsException);
      await expectLater(
        store.deleteSwapMasterKey(
          BoltzNetwork.mainnet,
          walletFingerprint: 'abc',
        ),
        throwsException,
      );
      expect(storage.entries, isEmpty);
    },
  );
}
