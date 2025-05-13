// Change 1: for each wallet with type as newSeed, change it to secure
// Change 2: add BaseWalletType as Bitcoin
// Change 3: add isLiquid to all Txns, Addresses
// Change 4: Update change address Index
// Change 5: create a new Liquid wallet, based on the Bitcoin wallet
import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_old_seed.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_wallets_metadatas.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_seed.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet.dart';
import 'package:crypto/crypto.dart';
import 'package:lwk/lwk.dart' as lwk;

// int mainWalletIndex = 0;
// int testWalletIndex = 0;

Future<void> doMigration0_1to0_2(
  OldSecureStorage secureStorage,
  OldHiveStorage hiveStorage,
) async {
  final oldWallets = fetchOldWalletMetadatas(hiveStorage);
  final walletIds = oldWallets.map((w) => w.id).toList();

  final List<OldWallet> wallets = [];

  OldSeed? liquidMainnetSeed;
  OldSeed? liquidTestnetSeed;

  for (final walletId in walletIds) {
    final jsn = hiveStorage.getValue(walletId);
    if (jsn == null) throw 'Abort';

    Map<String, dynamic> walletObj = jsonDecode(jsn) as Map<String, dynamic>;

    // Change 1: for each wallet with type as newSeed, change it to secure
    // Change 2: add BaseWalletType as Bitcoin
    final mnemonicFingerprint = walletObj['mnemonicFingerprint'] as String;
    final seed = await fetchOldSeed(
      secureStorage: secureStorage,
      fingerprintIndex: mnemonicFingerprint,
    );
    final res = await updateWalletObj(walletObj, seed);
    liquidMainnetSeed ??= res.liquidMainnetSeed;
    liquidTestnetSeed ??= res.liquidTestnetSeed;
    walletObj = res.walletObj;

    // Change 3: add isLiquid to all Txns, Addresses
    walletObj = await addIsLiquid(walletObj);

    final w = OldWallet.fromJson(walletObj);
    wallets.add(w);
  }

  // Change 4: create a new Liquid wallet, based on the Bitcoin wallet
  final liqWallets = await createLiquidWallet(
    liquidMainnetSeed,
    liquidTestnetSeed,
    hiveStorage,
  );

  wallets.addAll(liqWallets);

  final mainWalletIdx = wallets.indexWhere(
    (w) => !w.isTestnet() && w.isSecure(),
  );

  final liqMainnetIdx = wallets.indexWhere(
    (w) => !w.isTestnet() && w.isInstant(),
  );

  if (mainWalletIdx != -1 && liqMainnetIdx != -1) {
    if (wallets.length > 2) {
      final tempMain = wallets[mainWalletIdx];
      final tempLiq = wallets[liqMainnetIdx];
      wallets.removeAt(mainWalletIdx);
      wallets.removeAt(liqMainnetIdx - 1);
      wallets.insert(0, tempLiq);
      wallets.insert(1, tempMain);
    }
  }

  final walletObjs = wallets.map((w) => w.toJson()).toList();
  final List<String> ids = [];
  for (final w in walletObjs) {
    final id = w['id'] as String;
    ids.add(id);
    final _ = await hiveStorage.saveValue(key: id, value: jsonEncode(w));
  }

  final idsJsn = jsonEncode({
    'wallets': [...ids],
  });
  final _ = await hiveStorage.saveValue(
    key: OldStorageKeys.wallets.name,
    value: idsJsn,
  );

  // why arent we using toVersion and hardcoding 0.2 here?
  await secureStorage.saveValue(
    key: OldStorageKeys.version.name,
    value: '0.2.0',
  );
}

Future<
  ({
    OldSeed? liquidMainnetSeed,
    OldSeed? liquidTestnetSeed,
    Map<String, dynamic> walletObj,
  })
>
updateWalletObj(Map<String, dynamic> walletObj, OldSeed seed) async {
  OldSeed? liquidMainnetSeed;
  OldSeed? liquidTestnetSeed;

  int mainWalletIndex = 0;
  int testWalletIndex = 0;

  // TODO: Test this assumption
  // Assuming first wallet is to be changed to secure and further wallets to words
  // `newSeed` --> Auto created by wallet
  // `words` --> Wallet recovered by user
  if (walletObj['type'] == 'newSeed' || walletObj['type'] == 'words') {
    if (walletObj['network'] == 'Mainnet') {
      if (mainWalletIndex == 0) {
        walletObj['type'] = 'main';
        walletObj['name'] = 'Secure Bitcoin Wallet';
        walletObj['mainWallet'] = true;
        mainWalletIndex++;

        liquidMainnetSeed = seed;
        mainWalletIndex++;
      } else if (walletObj['type'] == 'newSeed') {
        walletObj['type'] = 'words';
        mainWalletIndex++;
      }
    } else if (walletObj['network'] == 'Testnet') {
      if (testWalletIndex == 0) {
        walletObj['type'] = 'main';
        walletObj['name'] = 'Secure Bitcoin Wallet';
        walletObj['mainWallet'] = true;
        testWalletIndex++;

        liquidTestnetSeed = seed;
        testWalletIndex++;
      } else if (walletObj['type'] == 'newSeed') {
        walletObj['type'] = 'words';
        testWalletIndex++;
      }
    }

    if (walletObj['type'] == 'xpub' || walletObj['type'] == 'coldcard') {
      walletObj['mainWallet'] = false;
    }
  }
  walletObj.addAll({'baseWalletType': 'Bitcoin'});

  final ({
    OldSeed? liquidMainnetSeed,
    OldSeed? liquidTestnetSeed,
    Map<String, dynamic> walletObj,
  })
  res = (
    liquidMainnetSeed: liquidMainnetSeed,
    liquidTestnetSeed: liquidTestnetSeed,
    walletObj: walletObj,
  );

  return res;
}

Future<Map<String, dynamic>> addIsLiquid(Map<String, dynamic> walletObj) async {
  walletObj['transactions'] =
      walletObj['transactions']
          .map((tx) => tx as Map<String, dynamic>)
          .map((tx) => tx..addAll({'isLiquid': false}))
          .toList();

  if (walletObj['myAddressBook'] != null) {
    walletObj['myAddressBook'] =
        walletObj['myAddressBook']
            .map((addr) => addr as Map<String, dynamic>)
            .map((addr) => addr..addAll({'isLiquid': false}))
            .toList();
  }

  if (walletObj['externalAddressBook'] != null) {
    walletObj['externalAddressBook'] =
        walletObj['externalAddressBook']
            .map((addr) => addr as Map<String, dynamic>)
            .map((addr) => addr..addAll({'isLiquid': false}))
            .toList();
  }

  return walletObj;
}

Future<List<OldWallet>> createLiquidWallet(
  OldSeed? liquidMainnetSeed,
  OldSeed? liquidTestnetSeed,
  OldHiveStorage hiveStorage,
) async {
  // create liquid wallet from lwk
  final List<OldWallet> oldWallets = [];
  if (liquidMainnetSeed != null) {
    final mnemonic = liquidMainnetSeed.mnemonic;
    final descriptor = lwk.Descriptor.newConfidential(
      mnemonic: mnemonic,
      network: lwk.Network.mainnet,
    );
    // Generate wallet ID
    final walletId = createDescriptorHashId(
      descriptor.toString(),
      OldBBNetwork.Mainnet,
    );
    // Create wallet object
    final walletObj = <String, dynamic>{
      'id': walletId,
      'name': 'Instant Payment Wallet',
      'type': 'main',
      'network': 'Mainnet',
      'mnemonicFingerprint': liquidMainnetSeed.mnemonicFingerprint,
      'sourceFingerprint': liquidMainnetSeed.mnemonicFingerprint,
      'baseWalletType': 'Liquid',
      'scriptType': OldScriptType.bip84.toString(),
      'externalDescriptor': descriptor,
      'internalDescriptor': descriptor,
      'mainWallet': true,
      'transactions': [],
      'myAddressBook': [],
      'externalAddressBook': [],
      'changeAddressIndex': 0,
      'receiveAddressIndex': 0,
    };

    oldWallets.add(OldWallet.fromJson(walletObj));
  }
  if (liquidTestnetSeed != null) {
    final mnemonic = liquidTestnetSeed.mnemonic;
    final descriptor = lwk.Descriptor.newConfidential(
      mnemonic: mnemonic,
      network: lwk.Network.testnet,
    );
    // Generate wallet ID
    final walletId = createDescriptorHashId(
      descriptor.toString(),
      OldBBNetwork.Testnet,
    );
    // Create wallet object
    final walletObj = <String, dynamic>{
      'id': walletId,
      'name': 'Instant Payment Wallet',
      'type': 'main',
      'network': 'Testnet',
      'mnemonicFingerprint': liquidTestnetSeed.mnemonicFingerprint,
      'sourceFingerprint': liquidTestnetSeed.mnemonicFingerprint,
      'baseWalletType': 'Liquid',
      'scriptType': OldScriptType.bip84.toString(),
      'externalDescriptor': descriptor,
      'internalDescriptor': descriptor,
      'mainWallet': true,
      'transactions': [],
      'myAddressBook': [],
      'externalAddressBook': [],
      'changeAddressIndex': 0,
      'receiveAddressIndex': 0,
    };

    oldWallets.add(OldWallet.fromJson(walletObj));
  }

  return oldWallets;
}

String createDescriptorHashId(String descriptor, OldBBNetwork network) {
  final descHashId = sha1
      .convert(
        utf8.encode(
          descriptor
                  .replaceFirst('/0/*', '/<0;1>/*')
                  .replaceFirst('/1/*', '/<0;1>/*') +
              network.toString(),
        ),
      )
      .toString()
      .substring(0, 12);
  return descHashId;
}
