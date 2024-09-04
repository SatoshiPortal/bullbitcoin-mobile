// Change 1: for each wallet with type as newSeed, change it to secure
//  Change 2: add BaseWalletType as Bitcoin
//  Change 3: add isLiquid to all Txns, Addresses
//  Change 4: Update change address Index
// Change 5: create a new Liquid wallet, based on the Bitcoin wallet
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

// int mainWalletIndex = 0;
// int testWalletIndex = 0;

Future<void> doMigration0_1to0_2(
  SecureStorage secureStorage,
  HiveStorage hiveStorage,
) async {
  final (walletIds, walletIdsErr) =
      await hiveStorage.getValue(StorageKeys.wallets);
  if (walletIdsErr != null) throw walletIdsErr;

  final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;
  if (walletIdsJson.isEmpty) throw 'No Wallets found';

  final WalletSensitiveStorageRepository walletSensitiveStorageRepository =
      WalletSensitiveStorageRepository(secureStorage: secureStorage);

  final List<Wallet> wallets = [];

  Seed? liquidMainnetSeed;
  Seed? liquidTestnetSeed;

  for (final walletId in walletIdsJson) {
    final (jsn, err) = await hiveStorage.getValue(walletId as String);
    if (err != null) throw err;

    Map<String, dynamic> walletObj = jsonDecode(jsn!) as Map<String, dynamic>;

    // Change 1: for each wallet with type as newSeed, change it to secure
    // Change 2: add BaseWalletType as Bitcoin
    final res =
        await updateWalletObj(walletObj, walletSensitiveStorageRepository);
    liquidMainnetSeed ??= res.liquidMainnetSeed;
    liquidTestnetSeed ??= res.liquidTestnetSeed;
    walletObj = res.walletObj;

    // Change 3: add isLiquid to all Txns, Addresses
    walletObj = await addIsLiquid(walletObj);

    final w = Wallet.fromJson(walletObj);
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
    final _ = await hiveStorage.saveValue(
      key: id,
      value: jsonEncode(w),
    );
  }

  final idsJsn = jsonEncode({
    'wallets': [...ids],
  });
  final _ = await hiveStorage.saveValue(
    key: StorageKeys.wallets,
    value: idsJsn,
  );

  // why arent we using toVersion and hardcoding 0.2 here?
  await secureStorage.saveValue(key: StorageKeys.version, value: '0.2.0');
}

Future<
    ({
      Seed? liquidMainnetSeed,
      Seed? liquidTestnetSeed,
      Map<String, dynamic> walletObj
    })> updateWalletObj(
  Map<String, dynamic> walletObj,
  WalletSensitiveStorageRepository walletSensitiveStorageRepository,
) async {
  Seed? liquidMainnetSeed;
  Seed? liquidTestnetSeed;

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

        final mnemonicFingerprint = walletObj['mnemonicFingerprint'] as String;
        final (seed, _) = await walletSensitiveStorageRepository.readSeed(
          fingerprintIndex: mnemonicFingerprint,
        );

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

        final mnemonicFingerprint = walletObj['mnemonicFingerprint'] as String;
        final (seed, _) = await walletSensitiveStorageRepository.readSeed(
          fingerprintIndex: mnemonicFingerprint,
        );

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
    Seed? liquidMainnetSeed,
    Seed? liquidTestnetSeed,
    Map<String, dynamic> walletObj
  }) res = (
    liquidMainnetSeed: liquidMainnetSeed,
    liquidTestnetSeed: liquidTestnetSeed,
    walletObj: walletObj,
  );

  return res;
}

// Some issue in old build(s), cause some indexes to be null.
// Skipping some addresses. This funciton will fix that
// TODO: Change address list count or max change address index.
//  --> Doing max change address will be complex. So need to finalize if its necessary.
// Future<Wallet> updateAddressNullIssue(
//   Map<String, dynamic> walletObj,
//   // bdk.Blockchain mainBlockchain,
//   // bdk.Blockchain testBlockchain,
// ) async {
//   final Wallet w = Wallet.fromJson(walletObj);
//   final WalletsRepository walletRepo = WalletsRepository();
//   final bdkCreate = BDKCreate(walletsRepository: walletRepo);
//   final (bdkWallet, _) = await bdkCreate.loadPublicBdkWallet(w);

//   final network = await bdkWallet!.network();
//   // await bdkWallet.sync(
//   //   blockchain:
//   //       network == bdk.Network.bitcoin ? mainBlockchain : testBlockchain,
//   // );

//   final myAddressBook = [...w.myAddressBook].toList();

//   final bdk.AddressInfo lastDepositAddr = await bdkWallet.getAddress(
//     addressIndex: const bdk.AddressIndex.lastUnused(),
//   );
//   final int depositAddressCount = lastDepositAddr.index;

//   final bdk.AddressInfo lastChangeAddr = await bdkWallet.getInternalAddress(
//     addressIndex: const bdk.AddressIndex.lastUnused(),
//   );
//   final int changeAddressCount = lastChangeAddr.index;
//   //int ivar = 0;
//   //w.myAddressBook.map((addr) {
//   //  if (addr.kind == AddressKind.change) {
//   //    changeAddressCount++;
//   //  } else if (addr.kind == AddressKind.deposit) {
//   //    depositAddressCount++;
//   //  }
//   //  ivar++;
//   //  return addr;
//   //}).toList();

//   final List<Address> toAdd = [];
//   for (int i = 0; i < depositAddressCount; i++) {
//     bdk.AddressInfo nativeAddr;
//     String nativeAddrStr;

//     nativeAddr = await bdkWallet.getAddress(
//       addressIndex: bdk.AddressIndex.peek(index: i),
//     );
//     nativeAddrStr = await nativeAddr.address.asString();

//     final matchIndex =
//         myAddressBook.indexWhere((a) => a.address == nativeAddrStr);
//     if (matchIndex != -1) {
//       final newAddr =
//           myAddressBook[matchIndex].copyWith(index: nativeAddr.index);
//       myAddressBook[matchIndex] = newAddr;
//     } else {
//       toAdd.add(
//         Address(
//           address: nativeAddrStr,
//           kind: AddressKind.deposit,
//           state: AddressStatus.unused,
//           index: nativeAddr.index,
//           // balance: 0, // TODO: Balance and other fields?
//         ),
//       );
//     }
//   }
//   myAddressBook.addAll(toAdd);

//   toAdd.clear();
//   for (int i = 0; i < changeAddressCount; i++) {
//     bdk.AddressInfo nativeAddr;
//     String nativeAddrStr;

//     nativeAddr = await bdkWallet.getInternalAddress(
//       addressIndex: bdk.AddressIndex.peek(index: i),
//     );
//     nativeAddrStr = await nativeAddr.address.asString();

//     final matchIndex =
//         myAddressBook.indexWhere((a) => a.address == nativeAddrStr);
//     if (matchIndex != -1) {

//       final newAddr =
//           myAddressBook[matchIndex].copyWith(index: nativeAddr.index);
//       myAddressBook[matchIndex] = newAddr;
//     } else {
//       toAdd.add(
//         Address(
//           address: nativeAddrStr,
//           kind: AddressKind.change,
//           state: AddressStatus.unused,
//           index: nativeAddr.index,
//           // balance: 0, // TODO: Balance and other fields?
//         ),
//       );
//     }
//   }
//   myAddressBook.addAll(toAdd);

//   // for (int i = 0; i < myAddressBook.length; i++) {
//   // }

//   return w.copyWith(
//     myAddressBook: myAddressBook,
//   );
// }

Future<Map<String, dynamic>> addIsLiquid(
  Map<String, dynamic> walletObj,
) async {
  walletObj['transactions'] = walletObj['transactions']
      .map((tx) => tx as Map<String, dynamic>)
      .map((tx) => tx..addAll({'isLiquid': false}))
      .toList();

  if (walletObj['myAddressBook'] != null) {
    walletObj['myAddressBook'] = walletObj['myAddressBook']
        .map((addr) => addr as Map<String, dynamic>)
        .map((addr) => addr..addAll({'isLiquid': false}))
        .toList();
  }

  // log(jsonEncode(walletObj['myAddressBook']));

  if (walletObj['externalAddressBook'] != null) {
    walletObj['externalAddressBook'] = walletObj['externalAddressBook']
        .map((addr) => addr as Map<String, dynamic>)
        .map((addr) => addr..addAll({'isLiquid': false}))
        .toList();
  }

  return walletObj;
}

Future<List<Wallet>> createLiquidWallet(
  Seed? liquidMainnetSeed,
  Seed? liquidTestnetSeed,
  HiveStorage hiveStorage,
) async {
  final WalletsRepository walletRep = WalletsRepository();
  final BDKCreate bdkCreate = BDKCreate(walletsRepository: walletRep);
  final BDKSensitiveCreate bdkSensitiveCreate =
      BDKSensitiveCreate(walletsRepository: walletRep, bdkCreate: bdkCreate);
  final LWKCreate lwkCreate = LWKCreate();
  final LWKSensitiveCreate lwkSensitiveCreate = LWKSensitiveCreate(
    bdkSensitiveCreate: bdkSensitiveCreate,
    lwkCreate: lwkCreate,
  );
  final WalletsStorageRepository walletsStorageRepository =
      WalletsStorageRepository(hiveStorage: hiveStorage);
  final WalletCreate walletCreate = WalletCreate(
    walletsRepository: walletRep,
    lwkCreate: lwkCreate,
    bdkCreate: bdkCreate,
    walletsStorageRepository: walletsStorageRepository,
  );

  final List<Wallet> wallets = [];

  if (liquidMainnetSeed != null) {
    final (lw, _) = await lwkSensitiveCreate.oneLiquidFromBIP39(
      seed: liquidMainnetSeed,
      passphrase: liquidMainnetSeed.passphrases.isNotEmpty
          ? liquidMainnetSeed.passphrases[0].passphrase
          : '',
      scriptType: ScriptType.bip84,
      walletType: BBWalletType.main,
      network: BBNetwork.Mainnet,
      walletCreate: walletCreate,
    );
    final liquidWallet =
        lw?.copyWith(name: lw.creationName(), mainWallet: true);
    wallets.add(liquidWallet!);
  }

  if (liquidTestnetSeed != null) {
    final (lw, _) = await lwkSensitiveCreate.oneLiquidFromBIP39(
      seed: liquidTestnetSeed,
      passphrase: liquidTestnetSeed.passphrases.isNotEmpty
          ? liquidTestnetSeed.passphrases[0].passphrase
          : '',
      scriptType: ScriptType.bip84,
      walletType: BBWalletType.main,
      network: BBNetwork.Testnet,
      walletCreate: walletCreate,
    );
    final liquidWallet =
        lw?.copyWith(name: lw.creationName(), mainWallet: true);

    wallets.add(liquidWallet!);
    await walletsStorageRepository.newWallet(liquidWallet);
  }
  return wallets;
}
