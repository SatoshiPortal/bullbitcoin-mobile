// Change 1: for each wallet with type as newSeed, change it to secure
//  Change 2: add BaseWalletType as Bitcoin
//  Change 3: add isLiquid to all Txns, Addresses
//  Change 4: Update change address Index
// Change 5: create a new Liquid wallet, based on the Bitcoin wallet
import 'dart:convert';

import 'package:bb_mobile/_model/address.dart';
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
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

Seed? liquidMainnetSeed;
Seed? liquidTestnetSeed;

Future<void> doMigration0_1to0_2(
  SecureStorage secureStorage,
  HiveStorage hiveStorage,
  bdk.Blockchain mainBlockchain,
  bdk.Blockchain testBlockchain,
) async {
  print('Migration: 0.1 to 0.2');

  final (walletIds, walletIdsErr) =
      await hiveStorage.getValue(StorageKeys.wallets);
  if (walletIdsErr != null) throw walletIdsErr;

  final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

  final WalletSensitiveStorageRepository walletSensitiveStorageRepository =
      WalletSensitiveStorageRepository(secureStorage: secureStorage);

  for (final walletId in walletIdsJson) {
    // print('walletId: $walletId');
    final (jsn, err) = await hiveStorage.getValue(walletId as String);
    if (err != null) throw err;

    Map<String, dynamic> walletObj = jsonDecode(jsn!) as Map<String, dynamic>;

    // Change 1: for each wallet with type as newSeed, change it to secure
    // Change 2: add BaseWalletType as Bitcoin
    walletObj =
        await updateWalletObj(walletObj, walletSensitiveStorageRepository);

    // Change 3: add isLiquid to all Txns, Addresses
    walletObj = await addIsLiquid(walletObj);

    // Change 4: Update change address Index
    walletObj =
        await updateAddressNullIssue(walletObj, mainBlockchain, testBlockchain);

    // print('Save wallet as:');
    // print(jsonEncode(walletObj));

    final _ = await hiveStorage.saveValue(
      key: walletId,
      value: jsonEncode(
        walletObj,
      ),
    );
  }

  // Change 4: create a new Liquid wallet, based on the Bitcoin wallet
  await createLiquidWallet(liquidMainnetSeed, liquidTestnetSeed, hiveStorage);

  // Finally update version number to next version
  await secureStorage.saveValue(key: StorageKeys.version, value: '0.2');
}

Future<Map<String, dynamic>> updateWalletObj(
  Map<String, dynamic> walletObj,
  WalletSensitiveStorageRepository walletSensitiveStorageRepository,
) async {
  int mainWalletIndex = 0;
  int testWalletIndex = 0;

  // TODO: Test this assumption
  // Assuming first wallet is to be changed to secure and further wallets to words
  // `newSeed` --> Auto created by wallet
  // `worlds` --> Wallet recovered by user
  if (walletObj['type'] == 'newSeed' || walletObj['type'] == 'words') {
    if (walletObj['network'] == 'Mainnet') {
      if (mainWalletIndex == 0) {
        walletObj['type'] = 'secure';
        walletObj['name'] =
            'Secure Bitcoin Wallet / ' + (walletObj['name'] as String);
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
        walletObj['name'] =
            'Secure Bitcoin Wallet / ' + (walletObj['name'] as String);
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
  return walletObj;
}

// Some issue in old build(s), cause some indexes to be null.
// Skipping some addresses. This funciton will fix that
// TODO: Change address list count or max change address index.
//  --> Doing max change address will be complex. So need to finalize if its necessary.
Future<Map<String, dynamic>> updateAddressNullIssue(
  Map<String, dynamic> walletObj,
  bdk.Blockchain mainBlockchain,
  bdk.Blockchain testBlockchain,
) async {
  final Wallet w = Wallet.fromJson(walletObj);
  final WalletsRepository walletRepo = WalletsRepository();
  final bdkCreate = BDKCreate(walletsRepository: walletRepo);
  final (bdkWallet, _) = await bdkCreate.loadPublicBdkWallet(w);

  await bdkWallet!.sync(
    blockchain: bdkWallet.network == BBNetwork.Mainnet
        ? mainBlockchain
        : testBlockchain,
  );

  final myAddressBook = [...w.myAddressBook].toList();

  final bdk.AddressInfo lastDepositAddr = await bdkWallet.getAddress(
    addressIndex: const bdk.AddressIndex.lastUnused(),
  );
  final int depositAddressCount = lastDepositAddr.index;

  final bdk.AddressInfo lastChangeAddr = await bdkWallet.getInternalAddress(
    addressIndex: const bdk.AddressIndex.lastUnused(),
  );
  final int changeAddressCount = lastChangeAddr.index;
  //int ivar = 0;
  //w.myAddressBook.map((addr) {
  //  if (addr.kind == AddressKind.change) {
  //    changeAddressCount++;
  //  } else if (addr.kind == AddressKind.deposit) {
  //    depositAddressCount++;
  //  }
  //  print(
  //    'myAddressbook[$ivar] : ${addr.index} ${addr.kind} : (${addr.address})',
  //  );
  //  ivar++;
  //  return addr;
  //}).toList();

  final List<Address> toAdd = [];
  for (int i = 0; i < depositAddressCount; i++) {
    bdk.AddressInfo nativeAddr;
    String nativeAddrStr;

    nativeAddr = await bdkWallet.getAddress(
      addressIndex: bdk.AddressIndex.peek(index: i),
    );
    nativeAddrStr = await nativeAddr.address.asString();

    final matchIndex =
        myAddressBook.indexWhere((a) => a.address == nativeAddrStr);
    // print('matchIndex $matchIndex $i $nativeAddrStr');
    if (matchIndex != -1) {
      // print(
      //   'myAddressbook.deposit index $i : ${nativeAddr.index} (${myAddressBook[matchIndex].address}, $nativeAddrStr)',
      // );
      final newAddr =
          myAddressBook[matchIndex].copyWith(index: nativeAddr.index);
      myAddressBook[matchIndex] = newAddr;
    } else {
      toAdd.add(
        Address(
          address: nativeAddrStr,
          kind: AddressKind.deposit,
          state: AddressStatus.unused,
          index: nativeAddr.index,
          // balance: 0, // TODO: Balance and other fields?
        ),
      );
    }
  }
  myAddressBook.addAll(toAdd);

  toAdd.clear();
  for (int i = 0; i < changeAddressCount; i++) {
    bdk.AddressInfo nativeAddr;
    String nativeAddrStr;

    nativeAddr = await bdkWallet.getInternalAddress(
      addressIndex: bdk.AddressIndex.peek(index: i),
    );
    nativeAddrStr = await nativeAddr.address.asString();

    final matchIndex =
        myAddressBook.indexWhere((a) => a.address == nativeAddrStr);
    // print('matchIndex $matchIndex $i');
    if (matchIndex != -1) {
      // print(
      //   'myAddressbook.change index $i : ${nativeAddr.index} (${myAddressBook[matchIndex].address}, $nativeAddrStr)',
      // );

      final newAddr =
          myAddressBook[matchIndex].copyWith(index: nativeAddr.index);
      myAddressBook[matchIndex] = newAddr;
    } else {
      toAdd.add(
        Address(
          address: nativeAddrStr,
          kind: AddressKind.change,
          state: AddressStatus.unused,
          index: nativeAddr.index,
          // balance: 0, // TODO: Balance and other fields?
        ),
      );
    }
  }
  myAddressBook.addAll(toAdd);

  // print('After patch:');
  // for (int i = 0; i < myAddressBook.length; i++) {
  // print(
  //   'myAddressbook[$i] : ${myAddressBook[i].index} ${myAddressBook[i].kind} : (${myAddressBook[i].address})',
  // );
  // }

  return w.copyWith(myAddressBook: myAddressBook).toJson();
}

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

Future<void> createLiquidWallet(
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
    final liquidWallet =
        lw?.copyWith(name: lw.creationName(), mainWallet: true);
    // print(liquidWallet?.id);
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
    final liquidWallet =
        lw?.copyWith(name: lw.creationName(), mainWallet: true);
    // print(liquidWallet?.id);
    await walletsStorageRepository.newWallet(liquidWallet!);
  }
}
