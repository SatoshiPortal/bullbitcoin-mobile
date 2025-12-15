// CHANGE 1: Update to swap object

import 'dart:convert';

import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_swap.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_wallet.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/old_hive_datasource.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/locator.dart';
import 'package:boltz/boltz.dart';

Future<void> doMigration0_2to0_3() async {
  final secureStorageDatasource = MigrationSecureStorageDatasource();
  final hiveDatasource = locator<OldHiveDatasource>();
  final oldWalletRepository = OldWalletRepository(hiveDatasource);

  final oldWallets = await oldWalletRepository.fetch();
  final walletIds = oldWallets.map((w) => w.id).toList();

  final List<OldWallet> wallets = [];

  for (final walletId in walletIds) {
    final jsn = hiveDatasource.getValue(walletId);
    if (jsn == null) throw 'Abort';

    final Map<String, dynamic> walletObj =
        jsonDecode(jsn) as Map<String, dynamic>;

    final updatedWalletObj = await updateSwaps(walletObj);

    final w = OldWallet.fromJson(updatedWalletObj);
    wallets.add(w);
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
    value: '0.3.0',
  );
}

Future<Map<String, dynamic>> updateSwaps(Map<String, dynamic> walletObj) async {
  walletObj['swaps'] =
      walletObj['swaps'].map((swapTx) => swapTx as Map<String, dynamic>).map((
        swapTx,
      ) {
        final isSubmarine = swapTx['isSubmarine'] == true;
        if (isSubmarine) {
          swapTx['lockupTxid'] = swapTx['txid'];
        } else {
          swapTx['claimTxid'] = swapTx['txid'];
        }

        swapTx['lnSwapDetails'] =
            OldLnSwapDetails(
              swapType:
                  swapTx['isSubmarine'] == true
                      ? SwapType.submarine
                      : SwapType.reverse,
              invoice:
                  swapTx['invoice'] != null
                      ? (swapTx['invoice'] as String)
                      : '', //TODO:
              boltzPubKey:
                  swapTx['boltzPubkey'] != null
                      ? (swapTx['boltzPubkey'] as String)
                      : '',
              keyIndex:
                  swapTx['keyIndex'] != null ? swapTx['keyIndex'] as int : 0,
              myPublicKey:
                  swapTx['publicKey'] != null
                      ? swapTx['publicKey'] as String
                      : '',
              electrumUrl:
                  swapTx['electrumUrl'] != null
                      ? swapTx['electrumUrl'] as String
                      : '',
              locktime:
                  swapTx['locktime'] != null ? swapTx['locktime'] as int : 0,
              sha256:
                  swapTx['sha256'] != null
                      ? swapTx['sha256'] as String
                      : '', // TODO: Should do this?
              // hash160: swapTx['hash160'] as String, // TODO: Should do this?
              // blindingKey:
              //     swapTx['blindingKey'] as String, // TODO: Should do this?
            ).toJson();
        return swapTx;
      }).toList();

  walletObj['transactions'] =
      walletObj['transactions'].map((tx) => tx as Map<String, dynamic>).map((
        tx,
      ) {
        final txHasSwap = tx['swapTx'] != null;
        final swapTxHasInvoice = txHasSwap && tx['swapTx']['invoice'] != null;
        if (swapTxHasInvoice) {
          final isSubmarine = tx['swapTx']['isSubmarine'] == true;
          if (isSubmarine) {
            tx['swapTx']['lockupTxid'] = tx['swapTx']['txid'];
          } else {
            tx['swapTx']['claimTxid'] = tx['swapTx']['txid'];
          }

          tx['swapTx']['lnSwapDetails'] =
              OldLnSwapDetails(
                swapType: isSubmarine ? SwapType.submarine : SwapType.reverse,
                invoice: tx['swapTx']['invoice'] as String,
                boltzPubKey: tx['swapTx']['boltzPubkey'] as String,
                keyIndex:
                    tx['swapTx']['keyIndex'] != null
                        ? tx['swapTx']['keyIndex'] as int
                        : 0,
                myPublicKey: tx['swapTx']['publicKey'] as String,
                electrumUrl: tx['swapTx']['electrumUrl'] as String,
                locktime: tx['swapTx']['locktime'] as int,
                sha256:
                    tx['swapTx']['sha256'] != null
                        ? tx['swapTx']['sha256'] as String
                        : '',
                hash160:
                    tx['swapTx']['hash160'] != null
                        ? tx['swapTx']['hash160'] as String
                        : '',
                blindingKey:
                    tx['swapTx']['hash160'] != null
                        ? tx['swapTx']['blindingKey'] as String
                        : '',
              ).toJson();
          return tx;
        }
        return tx;
      }).toList();

  return walletObj;
}
