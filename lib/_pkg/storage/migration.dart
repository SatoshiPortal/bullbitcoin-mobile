import 'dart:convert';

import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';

Future<void> doMigration(String fromVersion, String toVersion, HiveStorage hiveStorage) async {
  print('fromVersion $fromVersion; toVersion $toVersion');
  if (toVersion.startsWith('0.2') && fromVersion.startsWith('0.1')) {
    await doMigration01to02(hiveStorage);
  } else if (toVersion.startsWith('0.3')) {
    if (fromVersion.startsWith('0.1')) {
      await doMigration01to02(hiveStorage);
      await doMigration02to03(hiveStorage);
    } else if (fromVersion.startsWith('0.2')) {
      await doMigration02to03(hiveStorage);
    }
  } else if (toVersion.startsWith('0.4')) {
    if (fromVersion.startsWith('0.1')) {
      await doMigration01to02(hiveStorage);
      await doMigration02to03(hiveStorage);
      await doMigration03to04(hiveStorage);
    } else if (fromVersion.startsWith('0.2')) {
      await doMigration02to03(hiveStorage);
      await doMigration03to04(hiveStorage);
    } else if (fromVersion.startsWith('0.3')) {
      await doMigration03to04(hiveStorage);
    }
  }
}

Future<void> doMigration01to02(HiveStorage hiveStorage) async {
  print('Migration: 0.1 to 0.2');
  // Change 1: for each wallet with type as newSeed, change it to secure
  // Change 2: add BaseWalletType as Bitcoin
  final (walletIds, walletIdsErr) = await hiveStorage.getValue(StorageKeys.wallets);
  if (walletIdsErr != null) throw walletIdsErr;

  final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;
  int mainWalletIndex = 0;
  int testWalletIndex = 0;
  for (final walletId in walletIdsJson) {
    final (jsn, err) = await hiveStorage.getValue(walletId as String);
    if (err != null) throw err;

    final walletObj = jsonDecode(jsn!) as Map<String, dynamic>;

    // Assuming first wallet is to be changed to secure and further wallets to words
    if (walletObj['type'] == 'newSeed') {
      if (walletObj['network'] == 'Mainnet') {
        if (mainWalletIndex == 0) {
          walletObj['type'] = 'secure';
          mainWalletIndex++;
        } else {
          walletObj['type'] = 'words';
          mainWalletIndex++;
        }
      } else if (walletObj['network'] == 'Testnet') {
        if (testWalletIndex == 0) {
          walletObj['type'] = 'secure';
          testWalletIndex++;
        } else {
          walletObj['type'] = 'words';
          testWalletIndex++;
        }
      }
    }
    walletObj.addAll({'baseWalletType': 'Bitcoin'});

    final _ = await hiveStorage.saveValue(
      key: walletId,
      value: jsonEncode(
        walletObj,
      ),
    );
  }

  // Step 3: create a new Liquid wallet, based on the Bitcoin wallet
}

Future<void> doMigration02to03(HiveStorage hiveStorage) async {
  print('Migration: 0.2 to 0.3');
}

Future<void> doMigration03to04(HiveStorage hiveStorage) async {
  print('Migration: 0.3 to 0.4');
}
