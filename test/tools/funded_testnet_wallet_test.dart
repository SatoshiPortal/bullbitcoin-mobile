import 'dart:io';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Mnemonic;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:sync/write.dart' show WalletNativeLifecycle;

import '../../integration_test/funded_testnet_wallet.dart';
import '../support/inventory_fixture.dart';

class _MockWalletNative extends Mock implements WalletNativeLifecycle {}

void main() {
  test(
    'reuses the funded testnet account after an earlier group imports it',
    () async {
      FakeSecureStoragePlatform().install();
      final directory = await Directory.systemTemp.createTemp('funded_wallet');
      addTearDown(() => directory.delete(recursive: true));
      final fixture = await InventoryFixture.open(directory);
      addTearDown(fixture.close);
      final secrets = Secrets(scratchDirectory: () async => directory.path);
      final mnemonic = Mnemonic(List<int>.filled(16, 0), Language.english);
      final native = _MockWalletNative();
      registerFallbackValue(
        WalletKey(id: 'fixture', network: BitcoinNetwork.testnet),
      );
      when(() => native.prepareCreate(any()))
          .thenAnswer((_) async => const Ok(null));
      when(() => native.create(any())).thenAnswer((_) async => const Ok(null));

      Future<WalletKey> openWallet() => openFundedTestnetWallet(
        mnemonic: mnemonic.sentence,
        secrets: secrets,
        inventory: fixture.inventory,
        native: native,
      );

      final key = await openWallet();
      expect(key.network, BitcoinNetwork.testnet);
      expect(await openWallet(), key);
      verify(() => native.prepareCreate(key)).called(1);
      verify(() => native.create(key)).called(1);
      verifyNoMoreInteractions(native);
    },
  );
}
