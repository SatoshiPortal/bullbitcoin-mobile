// Change 1: for each wallet with type as newSeed, change it to secure
// Change 2: add BaseWalletType as Bitcoin
// Change 3: add isLiquid to all Txns, Addresses
// Change 4: Update change address Index
// Change 5: create a new Liquid wallet, based on the Bitcoin wallet
import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_hive_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';

import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/locator.dart';
import 'package:crypto/crypto.dart';
import 'package:lwk/lwk.dart' as lwk;

Future<void> doMigration0_1to0_2() async {
  final print = locator<Logger>();

  try {
    final secureStorageDatasource = MigrationSecureStorageDatasource();
    final hiveDatasource = locator<OldHiveDatasource>();
    final oldSeedRepository = OldSeedRepository(secureStorageDatasource);

    final walletIdsRaw = hiveDatasource.getValue(OldStorageKeys.wallets.name);
    if (walletIdsRaw == null) throw 'No Wallets found';

    final walletIds = jsonDecode(walletIdsRaw)['wallets'] as List<dynamic>;
    if (walletIds.isEmpty) throw 'No Wallets found';

    final List<OldWallet> wallets = [];

    OldSeed? liquidMainnetSeed;
    bool isDefault = true;
    for (final walletId in walletIds) {
      final jsn = hiveDatasource.getValue(walletId as String);
      if (jsn == null) throw 'Abort';

      Map<String, dynamic> walletObj = jsonDecode(jsn) as Map<String, dynamic>;

      final mnemonicFingerprint = walletObj['mnemonicFingerprint'] as String;

      final seed = await oldSeedRepository.fetch(
        fingerprint: mnemonicFingerprint,
      );
      final res = await updateWalletObj(walletObj, seed, isDefault);
      liquidMainnetSeed ??= res.liquidMainnetSeed;
      walletObj = res.walletObj;
      if (liquidMainnetSeed != null) {
        isDefault = false;
      }

      walletObj = await addIsLiquid(walletObj);

      final w = OldWallet.fromJson(walletObj);
      wallets.add(w);
    }

    if (liquidMainnetSeed == null) {
      throw 'Could not create liquid mainnet wallet. Abort.';
    }
    final liqWallet = await createLiquidWallet(liquidMainnetSeed);

    wallets.addAll([liqWallet]);

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
      final _ = await hiveDatasource.saveValue(key: id, value: jsonEncode(w));
    }

    final idsJsn = jsonEncode({
      'wallets': [...ids],
    });
    final _ = await hiveDatasource.saveValue(
      key: OldStorageKeys.wallets.name,
      value: idsJsn,
    );

    await secureStorageDatasource.store(
      key: OldStorageKeys.version.name,
      value: '0.2.0',
    ); // gets overwritten by the exact 0.2.* version later}
  } catch (e) {
    print.log('Legacy Migration Failed: $e');
  }
}

Future<({OldSeed? liquidMainnetSeed, Map<String, dynamic> walletObj})>
updateWalletObj(
  Map<String, dynamic> walletObj,
  OldSeed? seed,
  bool isDefault,
) async {
  OldSeed? liquidMainnetSeed;

  // TODO: Test this assumption
  // Assuming first wallet is to be changed to secure and further wallets to words
  // `newSeed` -->  Created by wallet
  // `words` --> Wallet recovered by user
  if (walletObj['type'] == 'newSeed' || walletObj['type'] == 'words') {
    if (walletObj['network'] == 'Mainnet') {
      if (isDefault) {
        walletObj['type'] = 'main';
        walletObj['name'] = 'Secure Bitcoin';
        walletObj['mainWallet'] = true;

        liquidMainnetSeed = seed;
      } else if (walletObj['type'] == 'newSeed') {
        walletObj['type'] = 'words';
        walletObj['mainWallet'] = false;
      }
    }

    if (walletObj['type'] == 'xpub' || walletObj['type'] == 'coldcard') {
      walletObj['mainWallet'] = false;
    }
  }
  walletObj.addAll({'baseWalletType': 'Bitcoin'});

  final ({OldSeed? liquidMainnetSeed, Map<String, dynamic> walletObj}) res = (
    liquidMainnetSeed: liquidMainnetSeed,
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

Future<OldWallet> createLiquidWallet(OldSeed liquidMainnetSeed) async {
  final mnemonic = liquidMainnetSeed.mnemonic;
  final descriptor = await lwk.Descriptor.newConfidential(
    mnemonic: mnemonic,
    network: lwk.Network.mainnet,
  );
  final walletId = createDescriptorHashId(
    descriptor.ctDescriptor,
    OldBBNetwork.Mainnet,
  );
  final walletObj = <String, dynamic>{
    'id': walletId,
    'name': 'Instant Payments',
    'type': 'main',
    'network': OldBBNetwork.Mainnet.name,
    'mnemonicFingerprint': liquidMainnetSeed.mnemonicFingerprint,
    'sourceFingerprint': liquidMainnetSeed.mnemonicFingerprint,
    'baseWalletType': 'Liquid',
    'scriptType': OldScriptType.bip84.name,
    'externalDescriptor': descriptor.ctDescriptor,
    'internalDescriptor': descriptor.ctDescriptor,
    'mainWallet': true,
    'transactions': [],
    'myAddressBook': [],
    'externalAddressBook': [],
    'changeAddressIndex': 0,
    'receiveAddressIndex': 0,
  };

  return OldWallet.fromJson(walletObj);
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
