import 'dart:convert';

import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/create.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/wallets.dart';

Future<void> doMigration(
  String fromVersion,
  String toVersion,
  SecureStorage secureStorage,
  HiveStorage hiveStorage,
) async {
  print('fromVersion $fromVersion; toVersion $toVersion');
  if (toVersion.startsWith('0.2') && fromVersion.startsWith('0.1')) {
    await doMigration01to02(secureStorage, hiveStorage);
  } else if (toVersion.startsWith('0.3')) {
    if (fromVersion.startsWith('0.1')) {
      await doMigration01to02(secureStorage, hiveStorage);
      await doMigration02to03(secureStorage, hiveStorage);
    } else if (fromVersion.startsWith('0.2')) {
      await doMigration02to03(secureStorage, hiveStorage);
    }
  } else if (toVersion.startsWith('0.4')) {
    if (fromVersion.startsWith('0.1')) {
      await doMigration01to02(secureStorage, hiveStorage);
      await doMigration02to03(secureStorage, hiveStorage);
      await doMigration03to04(secureStorage, hiveStorage);
    } else if (fromVersion.startsWith('0.2')) {
      await doMigration02to03(secureStorage, hiveStorage);
      await doMigration03to04(secureStorage, hiveStorage);
    } else if (fromVersion.startsWith('0.3')) {
      await doMigration03to04(secureStorage, hiveStorage);
    }
  }
}

// Change 1: for each wallet with type as newSeed, change it to secure
// Change 2: add BaseWalletType as Bitcoin
// Change 3: create a new Liquid wallet, based on the Bitcoin wallet
Future<void> doMigration01to02(SecureStorage secureStorage, HiveStorage hiveStorage) async {
  print('Migration: 0.1 to 0.2');
  // Change 1: for each wallet with type as newSeed, change it to secure
  // Change 2: add BaseWalletType as Bitcoin
  final (walletIds, walletIdsErr) = await hiveStorage.getValue(StorageKeys.wallets);
  if (walletIdsErr != null) throw walletIdsErr;

  final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

  final WalletSensitiveStorageRepository walletSensitiveStorageRepository =
      WalletSensitiveStorageRepository(secureStorage: secureStorage);

  int mainWalletIndex = 0;
  int testWalletIndex = 0;
  Seed? liquidMainnetSeed;
  Seed? liquidTestnetSeed;
  for (final walletId in walletIdsJson) {
    final (jsn, err) = await hiveStorage.getValue(walletId as String);
    if (err != null) throw err;

    final walletObj = jsonDecode(jsn!) as Map<String, dynamic>;

    // TODO: Test this assumption
    // Assuming first wallet is to be changed to secure and further wallets to words
    // `newSeed` --> Auto created by wallet
    // `worlds` --> Wallet recovered by user
    if (walletObj['type'] == 'newSeed' || walletObj['type'] == 'words') {
      if (walletObj['network'] == 'Mainnet') {
        if (mainWalletIndex == 0) {
          walletObj['type'] = 'secure';
          walletObj['name'] = 'Secure Bitcoin Wallet / ' + (walletObj['name'] as String);
          walletObj['mainWallet'] = true;
          mainWalletIndex++;

          final mnemonicFingerprint = walletObj['mnemonicFingerprint'] as String;
          final (seed, _) = await walletSensitiveStorageRepository.readSeed(
            fingerprintIndex: mnemonicFingerprint,
          );

          liquidMainnetSeed = seed;
        } else {
          walletObj['type'] = 'words';
          mainWalletIndex++;
        }
      } else if (walletObj['network'] == 'Testnet') {
        if (testWalletIndex == 0) {
          walletObj['type'] = 'secure';
          walletObj['name'] = 'Secure Bitcoin Wallet / ' + (walletObj['name'] as String);
          walletObj['mainWallet'] = true;
          testWalletIndex++;

          final mnemonicFingerprint = walletObj['mnemonicFingerprint'] as String;
          final (seed, _) = await walletSensitiveStorageRepository.readSeed(
            fingerprintIndex: mnemonicFingerprint,
          );

          liquidTestnetSeed = seed;
        } else {
          walletObj['type'] = 'words';
          testWalletIndex++;
        }
      }
    }
    walletObj.addAll({'baseWalletType': 'Bitcoin'});

    print('Save wallet as:');
    print(jsonEncode(walletObj));

    final _ = await hiveStorage.saveValue(
      key: walletId,
      value: jsonEncode(
        walletObj,
      ),
    );
  }

  // Change 3: create a new Liquid wallet, based on the Bitcoin wallet
  final WalletsRepository walletRep = WalletsRepository();
  final BDKCreate bdkCreate = BDKCreate(walletsRepository: walletRep);
  final BDKSensitiveCreate bdkSensitiveCreate =
      BDKSensitiveCreate(walletsRepository: walletRep, bdkCreate: bdkCreate);
  final LWKCreate lwkCreate = LWKCreate();
  final LWKSensitiveCreate lwkSensitiveCreate =
      LWKSensitiveCreate(bdkSensitiveCreate: bdkSensitiveCreate, lwkCreate: lwkCreate);
  final WalletsStorageRepository walletsStorageRepository =
      WalletsStorageRepository(hiveStorage: hiveStorage);
  final WalletCreate walletCreate = WalletCreate(
    walletsRepository: walletRep,
    lwkCreate: lwkCreate,
    bdkCreate: bdkCreate,
    walletsStorageRepository: walletsStorageRepository,
  );

  if (liquidMainnetSeed != null) {
    final (lw, _) = await lwkSensitiveCreate.oneLiquidFromBIP39(
      seed: liquidMainnetSeed,
      passphrase: liquidMainnetSeed.passphrases.isNotEmpty
          ? liquidMainnetSeed.passphrases[0].passphrase
          : '',
      scriptType: ScriptType.bip84,
      walletType: BBWalletType.instant,
      network: BBNetwork.Mainnet,
      walletCreate: walletCreate,
    );
    final liquidWallet = lw?.copyWith(name: lw.creationName(), mainWallet: true);
    print(liquidWallet?.id);
    await walletsStorageRepository.newWallet(liquidWallet!);
  }

  if (liquidTestnetSeed != null) {
    final (lw, _) = await lwkSensitiveCreate.oneLiquidFromBIP39(
      seed: liquidTestnetSeed,
      passphrase: liquidTestnetSeed.passphrases.isNotEmpty
          ? liquidTestnetSeed.passphrases[0].passphrase
          : '',
      scriptType: ScriptType.bip84,
      walletType: BBWalletType.instant,
      network: BBNetwork.Testnet,
      walletCreate: walletCreate,
    );
    final liquidWallet = lw?.copyWith(name: lw.creationName(), mainWallet: true);
    print(liquidWallet?.id);
    await walletsStorageRepository.newWallet(liquidWallet!);
  }

  // Finally update version number to next version
  await secureStorage.saveValue(key: StorageKeys.version, value: '0.2');
}

Future<void> doMigration02to03(SecureStorage secureStorage, HiveStorage hiveStorage) async {
  print('Migration: 0.2 to 0.3');
}

Future<void> doMigration03to04(SecureStorage secureStorage, HiveStorage hiveStorage) async {
  print('Migration: 0.3 to 0.4');
}
