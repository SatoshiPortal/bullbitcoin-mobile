import 'dart:convert';

import 'package:bb_mobile/_model/swap.dart';
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
  final (walletIds, walletIdsErr) =
      await hiveStorage.getValue(StorageKeys.wallets);
  if (walletIdsErr != null) throw walletIdsErr;

  final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;
  if (walletIdsJson.isEmpty) throw 'No Wallets found';

  final WalletSensitiveStorageRepository walletSensitiveStorageRepository =
      WalletSensitiveStorageRepository(secureStorage: secureStorage);

  final List<Wallet> wallets = [];

  for (final walletId in walletIdsJson) {
    final (jsn, err) = await hiveStorage.getValue(walletId as String);
    if (err != null) throw err;

    final Map<String, dynamic> walletObj =
        jsonDecode(jsn!) as Map<String, dynamic>;

    final updatedWalletObj =
        await updateSwaps(walletObj, walletSensitiveStorageRepository);

    final w = Wallet.fromJson(updatedWalletObj);
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

  // why arent we using toVersion and hardcoding 0.2 here?
  await secureStorage.saveValue(key: StorageKeys.version, value: '0.3.0');
}

Future<Map<String, dynamic>> updateSwaps(
  Map<String, dynamic> walletObj,
  WalletSensitiveStorageRepository walletSensitiveStorageRepository,
) async {
  walletObj['swaps'] = walletObj['swaps']
      .map((swapTx) => swapTx as Map<String, dynamic>)
      .map((swapTx) {
    final isSubmarine = swapTx['isSubmarine'] == true;
    if (isSubmarine) {
      swapTx['lockupTxid'] = swapTx['txid'];
    } else {
      swapTx['claimTxid'] = swapTx['txid'];
    }

    swapTx['lnSwapDetails'] = LnSwapDetails(
      swapType:
          swapTx['isSubmarine'] == true ? SwapType.submarine : SwapType.reverse,
      invoice: swapTx['invoice'] != null
          ? (swapTx['invoice'] as String)
          : '', //TODO:
      boltzPubKey: swapTx['boltzPubkey'] != null
          ? (swapTx['boltzPubkey'] as String)
          : '',
      keyIndex: swapTx['keyIndex'] != null ? swapTx['keyIndex'] as int : 0,
      myPublicKey:
          swapTx['publicKey'] != null ? swapTx['publicKey'] as String : '',
      electrumUrl:
          swapTx['electrumUrl'] != null ? swapTx['electrumUrl'] as String : '',
      locktime: swapTx['locktime'] != null ? swapTx['locktime'] as int : 0,
      sha256: swapTx['sha256'] != null
          ? swapTx['sha256'] as String
          : '', // TODO: Should do this?
      // hash160: swapTx['hash160'] as String, // TODO: Should do this?
      // blindingKey:
      //     swapTx['blindingKey'] as String, // TODO: Should do this?
    ).toJson();
    return swapTx;
  }).toList();

  walletObj['transactions'] = walletObj['transactions']
      .map((tx) => tx as Map<String, dynamic>)
      .map((tx) {
    final txHasSwap = tx['swapTx'] != null;
    final swapTxHasInvoice = txHasSwap && tx['swapTx']['invoice'] != null;
    if (swapTxHasInvoice) {
      final isSubmarine = tx['swapTx']['isSubmarine'] == true;
      if (isSubmarine) {
        tx['swapTx']['lockupTxid'] = tx['swapTx']['txid'];
      } else {
        tx['swapTx']['claimTxid'] = tx['swapTx']['txid'];
      }

      tx['swapTx']['lnSwapDetails'] = LnSwapDetails(
        swapType: isSubmarine ? SwapType.submarine : SwapType.reverse,
        invoice: tx['swapTx']['invoice'] as String,
        boltzPubKey: tx['swapTx']['boltzPubkey'] as String,
        keyIndex: tx['swapTx']['keyIndex'] != null
            ? tx['swapTx']['keyIndex'] as int
            : 0,
        myPublicKey: tx['swapTx']['publicKey'] as String,
        electrumUrl: tx['swapTx']['electrumUrl'] as String,
        locktime: tx['swapTx']['locktime'] as int,
        sha256: tx['swapTx']['sha256'] != null
            ? tx['swapTx']['sha256'] as String
            : '',
        hash160: tx['swapTx']['hash160'] != null
            ? tx['swapTx']['hash160'] as String
            : '',
        blindingKey: tx['swapTx']['hash160'] != null
            ? tx['swapTx']['blindingKey'] as String
            : '',
      ).toJson();
      return tx;
    }
    return tx;
  }).toList();

  return walletObj;
}
