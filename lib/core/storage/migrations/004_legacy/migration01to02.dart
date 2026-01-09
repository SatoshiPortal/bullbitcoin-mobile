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
  try {
    final secureStorageDatasource = locator<MigrationSecureStorageDatasource>();
    final hiveDatasource = locator<OldHiveDatasource>();
    final oldSeedRepository = OldSeedRepository(secureStorageDatasource);

    final walletIdsRaw = hiveDatasource.getValue(OldStorageKeys.wallets.name);
    if (walletIdsRaw == null) throw 'No Wallets found';

    final walletIds = jsonDecode(walletIdsRaw)['wallets'] as List<dynamic>;
    if (walletIds.isEmpty) throw 'No Wallets found';
    log.info('0.1.*: Found ${walletIds.length} wallets');

    final List<OldWallet> wallets = [];

    OldSeed? liquidMainnetSeed;
    bool isDefault = true;
    log.info('0.1.*: Starting wallet migration');

    for (final walletId in walletIds) {
      try {
        final jsn = hiveDatasource.getValue(walletId as String);
        if (jsn == null) {
          log.warning('0.1.*: Wallet data not found for ID: $walletId');
          continue;
        }

        Map<String, dynamic> walletObj =
            jsonDecode(jsn) as Map<String, dynamic>;
        log.info(
          '0.1.*: Processing wallet ${walletObj['id']}, type: ${walletObj['type']}, network: ${walletObj['network']}',
        );

        final mnemonicFingerprint = walletObj['mnemonicFingerprint'] as String;
        OldSeed? seed;
        try {
          seed = await oldSeedRepository.fetch(
            fingerprint: mnemonicFingerprint,
          );
        } catch (e) {
          log.severe(
            '0.1.*: Failed to fetch seed for wallet ${walletObj['id']}',
          );
        }

        final res = await updateWalletObj(walletObj, seed, isDefault);
        liquidMainnetSeed ??= res.liquidMainnetSeed;
        walletObj = res.walletObj;
        if (liquidMainnetSeed != null) {
          isDefault = false;
        }

        log.info(
          '0.1.*: Updated wallet ${walletObj['id']} to type: ${walletObj['type']}, mainWallet: ${walletObj['mainWallet']}',
        );

        walletObj = await addIsLiquidFalse(walletObj);

        final w = OldWallet.fromJson(walletObj);
        wallets.add(w);
      } catch (e) {
        log.severe('0.1.*: Error processing wallet $walletId: $e');
        continue;
      }
    }

    if (liquidMainnetSeed == null) {
      throw 'Could not create liquid mainnet wallet. No valid mainnet seed found.';
    }

    log.info('0.1.*: Creating liquid wallet from mainnet seed');
    final liqWallet = await createLiquidWallet(liquidMainnetSeed);
    wallets.addAll([liqWallet]);
    log.info('0.1.*: Liquid wallet created successfully');

    final walletObjs = wallets.map((w) => w.toJson()).toList();
    final List<String> ids = [];
    for (final w in walletObjs) {
      final id = w['id'] as String;
      ids.add(id);
      final _ = await hiveDatasource.saveValue(key: id, value: jsonEncode(w));
      log.info('0.1.*: Saved migrated wallet $id');
    }

    final idsJsn = jsonEncode({
      'wallets': [...ids],
    });
    final _ = await hiveDatasource.saveValue(
      key: OldStorageKeys.wallets.name,
      value: idsJsn,
    );

    final walletIdsRawPost = hiveDatasource.getValue(
      OldStorageKeys.wallets.name,
    );
    if (walletIdsRawPost == null) throw 'No Wallets found after migration';

    final walletIdsPost =
        jsonDecode(walletIdsRawPost)['wallets'] as List<dynamic>;
    if (walletIdsPost.isEmpty) throw 'No Wallets found after migration';
    log.info(
      '0.1.*: Migration completed. Total wallets: ${walletIdsPost.length}',
    );

    await secureStorageDatasource.store(
      key: OldStorageKeys.version.name,
      value: '0.2.0',
    ); // gets overwritten by the exact 0.2.* version later
  } catch (e, stack) {
    log.severe('Legacy Migration Failed', error: e, trace: stack);
    rethrow;
  }
}

Future<({OldSeed? liquidMainnetSeed, Map<String, dynamic> walletObj})>
updateWalletObj(
  Map<String, dynamic> walletObj,
  OldSeed? seed,
  bool isDefault,
) async {
  OldSeed? liquidMainnetSeed;
  final originalType = walletObj['type'];
  final network = walletObj['network'];

  log.info(
    '0.1.*: updateWalletObj - Processing wallet ${walletObj['id']}: type=$originalType, network=$network, isDefault=$isDefault',
  );

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
        log.info(
          '0.1.*: Converted mainnet wallet to main type: ${walletObj['id']}',
        );
      } else {
        walletObj['type'] = 'words';
        walletObj['mainWallet'] = false;
        log.info(
          '0.1.*: Converted mainnet wallet to words type: ${walletObj['id']}',
        );
      }
    } else {
      walletObj['type'] = 'words';
      walletObj['mainWallet'] = false;
      log.info(
        '0.1.*: Converted non-mainnet wallet to words type: ${walletObj['id']}',
      );
    }
  } else if (walletObj['type'] == 'xpub' || walletObj['type'] == 'coldcard') {
    walletObj['mainWallet'] = false;
    log.info('0.1.*: Updated watch-only wallet: ${walletObj['id']}');
  }

  walletObj.addAll({'baseWalletType': 'Bitcoin'});

  log.info(
    '0.1.*: Wallet ${walletObj['id']} final state - type: ${walletObj['type']}, mainWallet: ${walletObj['mainWallet']}, baseWalletType: ${walletObj['baseWalletType']}',
  );

  final ({OldSeed? liquidMainnetSeed, Map<String, dynamic> walletObj}) res = (
    liquidMainnetSeed: liquidMainnetSeed,
    walletObj: walletObj,
  );

  return res;
}

Future<Map<String, dynamic>> addIsLiquidFalse(
  Map<String, dynamic> walletObj,
) async {
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
