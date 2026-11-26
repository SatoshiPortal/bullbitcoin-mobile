import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'support/real_swap_backends.dart';

import 'package:swaps/src/data/models/boltz_network.dart';
import 'package:swaps/src/data/models/swap_master_key_model.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/data/db/boltz_swaps_database.dart';
import 'package:swaps/src/data/db/drift_swap_row_store.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('deleting a testnet master key preserves the regtest allocation high-water mark', () async {
    final productionDb = BoltzSwapsDatabase(NativeDatabase.memory());
    final regtestDb = BoltzSwapsDatabase(NativeDatabase.memory());
    addTearDown(productionDb.close);
    addTearDown(regtestDb.close);
    final keychain = ReproKeychainBackend();
    final canonical = SwapStorage(
      rows: DriftSwapRowStore(productionDb),
      secrets: keychain.capability,
    );
    final regtest = canonical.regtestView(rows: DriftSwapRowStore(regtestDb));
    await canonical.storeSwapMasterKey(
      const SwapMasterKeyModel(
        xprv: '',
        xpub: '',
        mnemonic: '',
        network: 'testnet',
        fingerprint: '00000001',
      ),
      walletFingerprint: '00000002',
    );
    final usedStart = await canonical.reserveSwapKeyIndex('00000001', 2, 0);
    await canonical.deleteSwapMasterKey(
      BoltzNetwork.testnet,
      walletFingerprint: '00000002',
    );
    final next = await regtest.reserveSwapKeyIndex('00000001', 1, 0);
    expect(next, greaterThan(usedStart + 1));
    expect(await canonical.getSwapKeyIndex('00000001'), 3);
    expect(
      await canonical.swapMasterKeyExists(
        BoltzNetwork.testnet,
        walletFingerprint: '00000002',
      ),
      isFalse,
    );
  });
}
