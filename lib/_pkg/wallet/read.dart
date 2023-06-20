import 'dart:convert';
import 'dart:isolate';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletRead {
  Future<(Wallet?, Err?)> getWalletDetails({
    required String saveDir,
    required IStorage storage,
    bool removeSensitive = false,
  }) async {
    try {
      final (jsn, err) = await storage.getWallet(saveDir);
      if (err != null) throw err;
      final obj = jsonDecode(jsn!) as Map<String, dynamic>;
      //add network and wallet type to obj
      // if (!obj.containsKey('network')) obj['network'] = 'Testnet';
      // if (!obj.containsKey('type')) obj['type'] = 'newSeed';
      // if (!obj.containsKey('walletType')) {
      //   obj['walletType'] = 'bip84';
      // } else {
      //   if (obj['walletType'] == 'bech32') {
      //     obj['walletType'] = 'bip84';
      //   } else if (obj['walletType'] == 'p2sh') {
      //     obj['walletType'] = 'bip49';
      //   } else if (obj['walletType'] == 'p2wpkh') {
      //     obj['walletType'] = 'bip84';
      //   }
      // }

      var wallet = Wallet.fromJson(obj);
      if (removeSensitive)
        wallet = wallet.copyWith(mnemonic: '', password: '', internalDescriptor: '');

      return (wallet, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<((Wallet, Balance)?, Err?)> getBalance({
    required bdk.Wallet bdkWallet,
    required Wallet wallet,
  }) async {
    try {
      final bdkbalance = await bdkWallet.getBalance();

      final balance = Balance(
        confirmed: bdkbalance.confirmed,
        untrustedPending: bdkbalance.untrustedPending,
        immature: bdkbalance.immature,
        trustedPending: bdkbalance.trustedPending,
        spendable: bdkbalance.spendable,
        total: bdkbalance.total,
      );

      final w = wallet.copyWith(balance: balance.total);

      return ((w, balance), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Wallet?, Err?)> getAddresses({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final unspentList = await bdkWallet.listUnspent();
      final addresses = wallet.addresses?.toList() ?? [];
      for (final unspent in unspentList) {
        final scr = await bdk.Script.create(unspent.txout.scriptPubkey.internal);
        final addresss = await bdk.Address.fromScript(
          scr,
          wallet.getBdkNetwork(),
        );
        final addressStr = addresss.toString();
        final address = addresses.firstWhere(
          (a) => a.address == addressStr,
          orElse: () => Address(
            address: addressStr,
            index: -1,
          ),
        );
        final utxos = address.utxos?.toList() ?? [];

        if (utxos.indexWhere((u) => u.outpoint.txid == unspent.outpoint.txid) == -1)
          utxos.add(unspent);

        var updated = address.copyWith(utxos: utxos);

        if (updated.calculateBalance() > 0 &&
            updated.calculateBalance() > updated.highestPreviousBalance)
          updated = updated.copyWith(highestPreviousBalance: updated.calculateBalance());

        if (updated.isReceive == null) updated = updated.copyWith(isReceive: updated.hasReceive());

        addresses.removeWhere((a) => a.address == address.address);
        addresses.add(updated);
      }
      final w = wallet.copyWith(addresses: addresses);

      return (w, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Wallet?, Err?)> getTransactions({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final storedTxs = wallet.transactions ?? [];
      final txs = await bdkWallet.listTransactions(true);
      // final x = bdk.TxBuilderResult();

      if (txs.isEmpty) throw 'No bdk transactions found';

      final List<Transaction> transactions = [];
      for (final tx in txs) {
        final idx = storedTxs.indexWhere((t) => t.txid == tx.txid);

        var txObj = Transaction(
          txid: tx.txid,
          received: tx.received,
          sent: tx.sent,
          fee: tx.fee ?? 0,
          height: tx.confirmationTime?.height ?? 0,
          timestamp: tx.confirmationTime?.timestamp ?? 0,
          bdkTx: tx,
          // label: label,
        );

        var label = '';

        final address = wallet.getAddressFromAddresses(
          txObj.txid,
          isSend: !txObj.isReceived(),
        );

        if (idx != -1 && storedTxs[idx].label != null && storedTxs[idx].label!.isNotEmpty)
          label = storedTxs[idx].label!;
        else if (address != null && address.label != null && address.label!.isNotEmpty)
          label = address.label!;

        if (txObj.isReceived()) {
          // final fromAddress = state.wallet!.getAddressFromTxid(txObj.txid);

          txObj = txObj.copyWith(
            toAddress: address?.address ?? '',
          );
        } else {
          final fromAddress = wallet.getAddressFromTxid(txObj.txid);
          if (idx != -1) {
            final broadcastTime = storedTxs[idx].broadcastTime;
            txObj = txObj.copyWith(broadcastTime: broadcastTime);
          }
          txObj = txObj.copyWith(
            toAddress: address?.address ?? '',
            fromAddress: fromAddress,
          );
        }

        transactions.add(txObj.copyWith(label: label));
      }

      final w = wallet.copyWith(transactions: transactions);

      return (w, null);
    } catch (e) {
      return (null, Err(e.toString(), expected: e.toString() == 'No bdk transactions found'));
    }
  }

  Future<(List<Wallet>?, Err?)> getWalletsFromStorage({
    required IStorage storage,
  }) async {
    try {
      final (walletsJsn, err) = await storage.getValue(StorageKeys.wallets);
      if (err != null) throw err;

      final walletsObjs = jsonDecode(walletsJsn!)['wallets'] as List<dynamic>;

      final List<Wallet> wallets = [];
      for (final w in walletsObjs) {
        try {
          final (wallet, err) = await getWalletDetails(
            saveDir: w as String,
            storage: storage,
          );
          if (err != null) continue;
          wallets.add(wallet!);
        } catch (e) {
          print(e);
        }
      }

      return (wallets, null);
    } catch (e) {
      return (null, Err(e.toString(), expected: e.toString() == 'No Key'));
    }
  }

  Future<(Transaction?, Err?)> getInputAddresses({
    required Transaction tx,
    required Wallet wallet,
    required MempoolAPI mempoolAPI,
  }) async {
    try {
      final isTestnet = wallet.network == BBNetwork.Testnet;

      final inputs = await tx.bdkTx!.transaction!.input();
      final inAddresses = await Future.wait(
        inputs.map((txIn) async {
          final idx = txIn.previousOutput.vout;
          final txid = txIn.previousOutput.txid;
          final (addresses, err) = await mempoolAPI.getVOutAddressesFromTx(txid, isTestnet);
          if (err != null) throw err;
          return addresses![idx];
        }),
      );

      final updated = tx.copyWith(inAddresses: inAddresses);

      return (updated, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Transaction?, Err?)> getOutputAddresses({
    required Transaction tx,
    required Wallet wallet,
    required MempoolAPI mempoolAPI,
  }) async {
    try {
      final outputs = await tx.bdkTx!.transaction!.output();
      final outAddresses = await Future.wait(
        outputs.map((txOut) async {
          final address = await bdk.Address.fromScript(
            txOut.scriptPubkey,
            wallet.getBdkNetwork(),
          );
          return address.toString();
        }),
      );

      final updated = tx.copyWith(outAddresses: outAddresses);

      return (updated, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  // Future<Err?> syncWallet({
  //   required bdk.Wallet bdkWallet,
  //   required bdk.Blockchain blockChain,
  // }) async {
  //   try {
  //     Isolate.run(() async => {await bdkWallet.sync(blockChain)});
  //     return null;
  //   } catch (e) {
  //     return Err(e.toString());
  //   }
  // }

  Future<(ReceivePort?, Err?)> sync2(bdk.Blockchain blockchain, bdk.Wallet wallet) async {
    try {
      final receivePort = ReceivePort();
      await Isolate.spawn(_sync, [receivePort.sendPort, wallet, blockchain]);
      return (receivePort, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<void> _sync(List<dynamic> args) async {
    final resultPort = args[0] as SendPort;
    final wallet = args[1] as bdk.Wallet;
    final blockchain = args[2] as bdk.Blockchain;
    await wallet.sync(blockchain);
    resultPort.send(true);
  }

  // Future<bool> sync2(bdk.Blockchain blockchain, bdk.Wallet wallet) async {
  //   final receivePort = ReceivePort();

  //   await Isolate.spawn(_sync, [receivePort.sendPort, wallet, blockchain]);
  //   final res = await receivePort.first;
  //   return res as bool;
  // }

  // Future<void> _sync(List<dynamic> args) async {
  //   final resultPort = args[0] as SendPort;
  //   final wallet = args[1] as bdk.Wallet;
  //   final blockchain = args[2] as bdk.Blockchain;
  //   await wallet.sync(blockchain);
  //   resultPort.send(true);
  // }
}
