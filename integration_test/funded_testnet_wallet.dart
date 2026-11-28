import 'package:bb_mobile/locator.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, ScriptType;
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import 'initialization_result.dart';

/// Coins and Payjoin use the same Alice account in the aggregated suite.
Future<WalletKey> openFundedTestnetWallet({
  required String mnemonic,
  required Secrets secrets,
  required SecretsInventory inventory,
  required WalletNativeLifecycle native,
}) async {
  final words = mnemonic.split(' ');
  const language = Language.english;
  final existing = requireValue(
    await secrets.find(words: words, language: language),
    'find the fixture secret',
  );
  final Secret secret =
      existing ??
      requireValue(
        await secrets.import(words: words, language: language),
        'import the fixture secret',
      );

  const network = BitcoinNetwork.testnet;
  const scriptType = ScriptType.bip84;
  final id = 'wpkh([${secret.id.hex}/84h/1h/0h])';
  final key = WalletKey(id: id, network: network);
  if (requireValue(await inventory.findWallet(id), 'read the fixture wallet') ==
      null) {
    // The account's public material is derived inside Secrets; only the
    // xpub and descriptors leave the package.
    final xpub = requireValue(
      await secret.derive.xpub(network: network, scriptType: scriptType),
      'derive the fixture xpub',
    );
    final descriptors = requireValue(
      await secret.derive.descriptors.bitcoin(
        network: network,
        scriptType: scriptType,
      ),
      'derive the fixture descriptors',
    );
    requireValue(await native.prepareCreate(key), 'prepare the fixture wallet');
    requireValue(
      await inventory.registerWallet(
        RegisteredWallet(
          id: id,
          secretFingerprint: secret.id.hex,
          masterFingerprint: secret.id.hex,
          signer: WalletSigner.local.name,
          network: 'bitcoinTestnet',
          xpub: xpub,
          externalDescriptor: descriptors.external,
          internalDescriptor: descriptors.internal,
          label: null,
          birthday: null,
          isDefault: false,
        ),
      ),
      'register the fixture wallet',
    );
    final created = await native.create(key);
    if (created is Err) {
      requireValue(
        await inventory.removeWallet(id),
        'remove the failed fixture',
      );
    }
    requireValue(created, 'create the fixture wallet');
  }
  return key;
}

Future<Wallet> syncFundedTestnetWallet(WalletKey key) async {
  final native = locator<WalletNativeRuntime>();
  requireValue(await native.initialize(), 'initialize Sync');
  final descriptor = requireValue(
    await locator<WalletCatalogPort>().find(key),
    'read the fixture descriptor',
  );
  requireValue(
    await locator<ElectrumSync>().execute(descriptor),
    'sync the fixture wallet',
  );
  requireValue(await native.refresh(key), 'publish the synced fixture wallet');
  return requireValue(await native.loadWallet(key), 'load the fixture wallet');
}
