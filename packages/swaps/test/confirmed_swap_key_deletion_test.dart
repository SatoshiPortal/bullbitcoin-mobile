import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:swaps/src/data/models/boltz_network.dart';
import 'package:swaps/src/data/models/swap_master_key_model.dart';
import 'package:swaps/src/data/swap_storage.dart';

class _Rows extends Mock implements SwapRowStore {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'deletes only the confirmed key in the confirmed wallet and network',
    () async {
      FakeSecureStoragePlatform().install();
      final store = SwapStorage(
        rows: _Rows(),
        secrets: Secrets(
          authority: unlockedSessionAuthority(),
          scratchDirectory: () async => Directory.systemTemp.path,
        ).swapKeychain,
      );
      const key = SwapMasterKeyModel(
        xprv: '',
        xpub: '',
        mnemonic: '',
        network: 'mainnet',
        fingerprint: 'key-a',
      );
      await store.storeSwapMasterKey(key, walletFingerprint: 'wallet-a');
      expect(
        await store.deleteSwapMasterKeyIfMatches(
          BoltzNetwork.mainnet,
          walletFingerprint: 'wallet-a',
          keyFingerprint: 'key-b',
        ),
        isFalse,
      );
      expect(
        await store.deleteSwapMasterKeyIfMatches(
          BoltzNetwork.testnet,
          walletFingerprint: 'wallet-a',
          keyFingerprint: 'key-a',
        ),
        isFalse,
      );
      expect(
        await store.deleteSwapMasterKeyIfMatches(
          BoltzNetwork.mainnet,
          walletFingerprint: 'wallet-b',
          keyFingerprint: 'key-a',
        ),
        isFalse,
      );
      expect(
        await store.deleteSwapMasterKeyIfMatches(
          BoltzNetwork.mainnet,
          walletFingerprint: 'wallet-a',
          keyFingerprint: 'key-a',
        ),
        isTrue,
      );
    },
  );
}
