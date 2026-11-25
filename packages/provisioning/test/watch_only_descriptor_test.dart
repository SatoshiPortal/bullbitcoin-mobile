import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:satoshifier/bip32_derivation.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

import 'support/fakes.dart';
import 'support/inventory_fixture.dart';

// Published BIP39 test-vector account (abandon … about), m/84'/0'/0'.
const _xpub =
    'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late InventoryFixture fixture;
  late WalletProvisioning accounts;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    directory = await Directory.systemTemp.createTemp('watch-only-xpub-');
    fixture = await InventoryFixture.open(directory);
    accounts = WalletProvisioning.open(
      inventory: fixture.inventory,
      native: FakeNativeLifecycle(),
      resume: () async => const Ok(null),
      properties: const [],
    );
  });

  tearDown(() async {
    await fixture.close();
    await directory.delete(recursive: true);
  });

  Future<RegisteredWallet> importXpub(ScriptType scriptType) async {
    expect(
      await accounts.importXpub(
        xpub: _xpub,
        network: BitcoinNetwork.mainnet,
        scriptType: scriptType,
        label: '',
      ),
      isA<Ok<void, WalletProvisioningFailure>>(),
    );
    return switch (await fixture.inventory.listWallets()) {
      Ok(value: final wallets) => wallets.single,
      Err(:final failure) => fail('listWallets: $failure'),
    };
  }

  for (final (scriptType, prefix, purpose) in [
    (ScriptType.bip84, 'wpkh(', 84),
    (ScriptType.bip49, 'sh(wpkh(', 49),
    (ScriptType.bip44, 'pkh(', 44),
  ]) {
    test('an imported xpub yields both $scriptType descriptors', () async {
      final row = await importXpub(scriptType);
      final fingerprint = Bip32Derivation.getBip32Xpub(_xpub).fingerprintHex;
      final origin = "[$fingerprint/$purpose'/0'/0']";
      expect(row.externalDescriptor, startsWith('$prefix$origin$_xpub/0/*)'));
      expect(row.internalDescriptor, startsWith('$prefix$origin$_xpub/1/*)'));
      expect(row.masterFingerprint, isEmpty);
      expect(row.secretFingerprint, isNull);
    });
  }
}
