import 'dart:async';
import 'dart:isolate';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

void _syncIsolate(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final bdkWallet = args[1] as bdk.Wallet;
  final blockChain = args[2] as bdk.Blockchain;

  try {
    await bdkWallet.sync(blockChain);
    sendPort.send(bdkWallet);
  } catch (e) {
    sendPort.send(
      Err(
        e.toString(),
        title: 'Error occurred while syncing wallet',
        solution: 'Please try again.',
      ),
    );
  }
}

class WalletSync {
  Isolate? _isolate;
  ReceivePort? _receivePort;

  Future<(bdk.Wallet?, Err?)> syncWallet({
    required bdk.Wallet bdkWallet,
    required bdk.Blockchain blockChain,
  }) async {
    try {
      final completer = Completer<(bdk.Wallet?, Err?)>();
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(_syncIsolate, [_receivePort!.sendPort, bdkWallet, blockChain]);

      _receivePort!.listen((message) {
        if (message is bdk.Wallet) {
          completer.complete((message, null));
        } else if (message is Err) {
          completer.complete((null, message));
        }
      });

      return completer.future;
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while syncing wallet',
          solution: 'Please try again.',
        )
      );
    }
  }

  void cancelSync() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
  }

  Future<(bdk.Blockchain?, Err?)> createBlockChain({
    required int stopGap,
    required int timeout,
    required int retry,
    required String url,
    required bool validateDomain,
  }) async {
    try {
      Uri.parse(url);
      if (locator.isRegistered<Logger>()) locator.get<Logger>().log('Connecting to $url');

      final blockchain = await bdk.Blockchain.create(
        config: bdk.BlockchainConfig.electrum(
          config: bdk.ElectrumConfig(
            url: url,
            retry: retry,
            timeout: timeout,
            stopGap: stopGap,
            validateDomain: validateDomain,
          ),
        ),
      );

      return (blockchain, null);
    } on Exception catch (r) {
      return (
        null,
        Err(
          r.message,
          // showAlert: true,
          title: 'Failed to connect to electrum',
        )
      );
    }
  }
}



  // Future<(ReceivePort?, Err?)> sync2(bdk.Blockchain blockchain, bdk.Wallet wallet) async {
  //   try {
  //     final receivePort = ReceivePort();
  //     await Isolate.spawn(_sync, [receivePort.sendPort, wallet, blockchain]);
  //     return (receivePort, null);
  //   } catch (e) {
  //     return (null, Err(e.message,
  // title: '',
  // solution: 'Please try again.',));
  //   }
  // }


// Future<void> _sync(List<dynamic> args) async {
//   final resultPort = args[0] as SendPort;
//   final wallet = args[1] as bdk.Wallet;
//   final blockchain = args[2] as bdk.Blockchain;
//   await wallet.sync(blockchain);
//   resultPort.send(true);
// }


/**
 * 
 *   Future<((Wallet, Balance)?, Err?)> getBalance({
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
      return (null, Err(e.message,
          title: '',
          solution: 'Please try again.',));
    }
  }

  Future<(({int index, String address})?, Err?)> getNewAddress({
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final address = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.new(),
      );

      return ((index: address.index, address: address.address), null);
    } catch (e) {
      return (null, Err(e.message,
          title: '',
          solution: 'Please try again.',));
    }
  }

  Future<String?> getAddressLabel({required Wallet wallet, required String address}) async {
    final addresses = wallet.addresses ?? <Address>[];

    String? label;
    if (addresses.any((element) => element.address == address)) {
      final x = addresses.firstWhere(
        (element) => element.address == address,
      );
      label = x.label;
    }

    return label;
  }

  Future<((int, String)?, Err?)> newAddress({
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final address = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex(),
      );

      return ((address.index, address.address), null);
    } catch (e) {
      return (null, Err(e.message,
          title: '',
          solution: 'Please try again.',));
    }
  }

  Future<(String?, Err?)> getAddressAtIdx(bdk.Wallet bdkWallet, int idx) async {
    try {
      final address = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.peek(index: 0),
      );

      return (address.address, null);
    } catch (e) {
      return (null, Err(e.message,
          title: '',
          solution: 'Please try again.',));
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
          updated = updated.copyWith(
            highestPreviousBalance: updated.calculateBalance(),
          );

        if (updated.isReceive == null) updated = updated.copyWith(isReceive: updated.hasReceive());

        addresses.removeWhere((a) => a.address == address.address);
        addresses.add(updated);
      }
      final w = wallet.copyWith(addresses: addresses);

      return (w, null);
    } catch (e) {
      return (null, Err(e.message,
          title: '',
          solution: 'Please try again.',));
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

        Transaction? storedTx;
        if (idx != -1) storedTx = storedTxs.elementAtOrNull(idx);

        var txObj = Transaction(
          txid: tx.txid,
          received: tx.received,
          sent: tx.sent,
          fee: tx.fee ?? 0,
          height: tx.confirmationTime?.height ?? 0,
          timestamp: tx.confirmationTime?.timestamp ?? 0,
          bdkTx: tx,
          rbfEnabled: storedTx?.rbfEnabled ?? false,
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
            fromAddress: '',
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
      return (null, Err(e.message,
          title: '',
          solution: 'Please try again.',));
    }
  }

  Future<(Transaction?, Err?)> getOutputAddresses({
    required Transaction tx,
    required Wallet wallet,
    required MempoolAPI mempoolAPI,
  }) async {
    try {
      final outputs = await tx.bdkTx!.transaction!.output();
      final (outAddresses) = await Future.wait(
        outputs.map((txOut) async {
          final address = await bdk.Address.fromScript(
            txOut.scriptPubkey,
            wallet.getBdkNetwork(),
          );
          final value = txOut.value;
          return address.toString() + ':$value';
        }),
      );

      final updated = tx.copyWith(outAddresses: outAddresses);

      return (updated, null);
    } catch (e) {
      return (null, Err(e.message,
          title: '',
          solution: 'Please try again.',));
    }
  }
*/
