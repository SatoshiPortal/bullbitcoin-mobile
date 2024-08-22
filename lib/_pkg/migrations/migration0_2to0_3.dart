// Change 1: move ln swap fields from SwapTx to SwapTx.lnSwapDetails
import 'dart:convert';

import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:boltz_dart/boltz_dart.dart';

Future<void> doMigration0_2to0_3(
  SecureStorage secureStorage,
  HiveStorage hiveStorage,
) async {
  print('Migration: 0.2 to 0.3');

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
    // print('walletId: $walletId');
    final (jsn, err) = await hiveStorage.getValue(walletId as String);
    if (err != null) throw err;

    final Map<String, dynamic> walletObj =
        jsonDecode(jsn!) as Map<String, dynamic>;

    final walletObj =
        await updateSwaps(walletObj, walletSensitiveStorageRepository);

    final w = Wallet.fromJson(walletObj);
    wallets.add(w);
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
  // Finally update version number to next version
  await secureStorage.saveValue(key: StorageKeys.version, value: '0.3');
}

Future<Map<String, dynamic>> updateSwaps(
  Map<String, dynamic> walletObj,
  WalletSensitiveStorageRepository walletSensitiveStorageRepository,
) async {
  walletObj['transactions'] = walletObj['transactions']
      .map((tx) => tx as Map<String, dynamic>)
      .map((tx) {
    if (tx['swap'] != null) {
      tx['swap'] = tx['swap']['lnSwapDetails'] = {};
      tx['swap']['lnSwapDetails']['swapType'] =
          tx['swap']['isSubmarine'] == true
              ? SwapType.submarine
              : SwapType.reverse;
      tx['swap']['lnSwapDetails']['invoice'] = tx['swap']['invoice'];
      tx['swap']['lnSwapDetails']['boltzPubKey'] = tx['swap']['boltzPubKey'];
      tx['swap']['lnSwapDetails']['keyIndex'] = tx['swap']['keyIndex'];
      tx['swap']['lnSwapDetails']['myPublicKey'] = tx['swap']['publicKey'];
      tx['swap']['lnSwapDetails']['sha256'] = tx['swap']['sha256'];
      tx['swap']['lnSwapDetails']['electrumUrl'] = tx['swap']['electrumUrl'];
      tx['swap']['lnSwapDetails']['locktime'] = tx['swap']['locktime'];
      tx['swap']['lnSwapDetails']['hash160'] = tx['swap']['hash160'];
      tx['swap']['lnSwapDetails']['blindingKey'] = tx['swap']['blindingKey'];
      return tx;
    }
    return tx;
  }).toList();

  return walletObj;
}
