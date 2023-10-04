import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:hex/hex.dart';

class WalletTx {
  //
  // THIS NEEDS WORK
  //
  Future<(Wallet?, Err?)> getTransactions({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      var updatedWallet = wallet;
      final storedTxs = wallet.transactions;
      final bdkNetwork = wallet.getBdkNetwork();
      final txs = await bdkWallet.listTransactions(true);
      // final x = bdk.TxBuilderResult();

      if (txs.isEmpty) return (wallet, null);

      final List<Transaction> transactions = [];
      for (final tx in txs) {
        String? label = '';

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
          outAddrs: storedTx?.outAddrs ?? [],
          // label: label,
        );
        final SerializedTx sTx = SerializedTx.fromJson(
          jsonDecode(txObj.bdkTx!.serializedTx!) as Map<String, dynamic>,
        );
        if (idx != -1 && storedTxs[idx].label != null && storedTxs[idx].label!.isNotEmpty)
          label = storedTxs[idx].label;

        Address? recipientAddress;
        Address? changeAddress;
        Address? depositAddress;
        const hexDecoder = HexDecoder();

        if (!txObj.isReceived()) {
          //
          //
          // HANDLE EXTERNAL RECIPIENT
          //
          //
          recipientAddress = updatedWallet.getAddressFromAddresses(
            txObj.txid,
            isSend: !txObj.isReceived(),
            kind: AddressKind.external,
          );
          if (recipientAddress != null &&
              recipientAddress.label != null &&
              recipientAddress.label!.isNotEmpty) label = recipientAddress.label;

          final amountSentToRecipient = tx.sent - (tx.received + (tx.fee ?? 0));

          if (recipientAddress != null)
            (recipientAddress, updatedWallet) = await WalletAddress().addAddressToWallet(
              address: (recipientAddress.index, recipientAddress.address),
              wallet: updatedWallet,
              spentTxId: tx.txid,
              kind: AddressKind.external,
              state: AddressStatus.used,
              spendable: false,
              label: label,
            );
          else {
            try {
              if (sTx.output == null) throw 'No output object';
              final scriptPubkeyString = sTx.output
                  ?.firstWhere((output) => output.value == amountSentToRecipient)
                  .scriptPubkey;
              // also check and update your own change, for older transactions
              // this can help keep an index of change?
              if (scriptPubkeyString == null) {
                throw 'No script pubkey';
              }
              final scriptPubKey = await bdk.Script.create(
                hexDecoder.convert(scriptPubkeyString) as Uint8List,
              );

              final addressStruct = await bdk.Address.fromScript(
                scriptPubKey,
                bdkNetwork,
              );

              (recipientAddress, updatedWallet) = await WalletAddress().addAddressToWallet(
                address: (null, addressStruct.toString()),
                wallet: updatedWallet,
                spentTxId: tx.txid,
                kind: AddressKind.external,
                state: AddressStatus.used,
                spendable: false,
                label: label,
              );
            } catch (e) {
              // usually scriptpubkey not available
              // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
              print(e);
            }
          }
          txObj = txObj.copyWith(
            toAddress: recipientAddress != null ? recipientAddress.address : '',
            fromAddress: '',
          );
          //
          //
          // HANDLE CHANGE
          //
          //

          changeAddress = updatedWallet.getAddressFromAddresses(
            txObj.txid,
            isSend: !txObj.isReceived(),
            kind: AddressKind.change,
          );
          if (changeAddress != null &&
              changeAddress.label != null &&
              changeAddress.label!.isNotEmpty) label = changeAddress.label;

          final amountChange = tx.received;

          if (changeAddress != null)
            (changeAddress, updatedWallet) = await WalletAddress().addAddressToWallet(
              address: (changeAddress.index, changeAddress.address),
              wallet: updatedWallet,
              spentTxId: tx.txid,
              kind: AddressKind.change,
              state: AddressStatus.used,
              spendable: false,
              label: label,
            );
          else {
            try {
              if (sTx.output == null) throw 'No output object';
              final scriptPubkeyString =
                  sTx.output?.firstWhere((output) => output.value == amountChange).scriptPubkey;

              if (scriptPubkeyString == null) {
                throw 'No script pubkey';
              }

              final scriptPubKey = await bdk.Script.create(
                hexDecoder.convert(scriptPubkeyString) as Uint8List,
              );
              final addressStruct = await bdk.Address.fromScript(
                scriptPubKey,
                bdkNetwork,
              );

              (changeAddress, updatedWallet) = await WalletAddress().addAddressToWallet(
                address: (null, addressStruct.toString()),
                wallet: wallet,
                spentTxId: tx.txid,
                kind: AddressKind.change,
                state: AddressStatus.used,
                spendable: false,
                label: label,
              );
            } catch (e) {
              // usually scriptpubkey not available
              // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
              print(e);
            }
          }
        } else if (txObj.isReceived()) {
          depositAddress = updatedWallet.getAddressFromAddresses(
            txObj.txid,
            isSend: !txObj.isReceived(),
            kind: AddressKind.deposit,
          );
          if (depositAddress != null &&
              depositAddress.label != null &&
              depositAddress.label!.isNotEmpty) label = depositAddress.label;

          final amountReceived = tx.received;

          if (depositAddress != null)
            (depositAddress, updatedWallet) = await WalletAddress().addAddressToWallet(
              address: (depositAddress.index, depositAddress.address),
              wallet: updatedWallet,
              spentTxId: tx.txid,
              kind: AddressKind.deposit,
              state: AddressStatus.used,
              spendable: false,
              label: label,
            );
          else {
            try {
              if (sTx.output == null) throw 'No output object';
              final scriptPubkeyString =
                  sTx.output?.firstWhere((output) => output.value == amountReceived).scriptPubkey;

              if (scriptPubkeyString == null) {
                throw 'No script pubkey';
              }

              final scriptPubKey = await bdk.Script.create(
                hexDecoder.convert(scriptPubkeyString) as Uint8List,
              );
              final addressStruct = await bdk.Address.fromScript(
                scriptPubKey,
                bdkNetwork,
              );

              (depositAddress, updatedWallet) = await WalletAddress().addAddressToWallet(
                address: (null, addressStruct.toString()),
                wallet: updatedWallet,
                spentTxId: tx.txid,
                kind: AddressKind.deposit,
                state: AddressStatus.used,
                spendable: false,
                label: label,
              );
            } catch (e) {
              // usually scriptpubkey not available
              // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
              print(e);
            }
          }
          txObj = txObj.copyWith(
            toAddress: depositAddress != null ? depositAddress.address : '',
            fromAddress: '',
          );
        }

        transactions.add(txObj.copyWith(label: label));
        // Future.delayed(const Duration(milliseconds: 100));
      }

      // Future.delayed(const Duration(milliseconds: 200));
      final Wallet w = updatedWallet.copyWith(
        transactions: transactions,
      );

      return (w, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<((Transaction?, int?, String)?, Err?)> buildTx({
    required Wallet wallet,
    required bdk.Wallet pubWallet,
    required bool isManualSend,
    required String address,
    required int? amount,
    required bool sendAllCoin,
    required double feeRate,
    required bool enableRbf,
    required List<Address> selectedAddresses,
    String? note,
  }) async {
    try {
      var txBuilder = bdk.TxBuilder();
      final bdkAddress = await bdk.Address.create(address: address);
      final script = await bdkAddress.scriptPubKey();

      if (sendAllCoin) {
        txBuilder = txBuilder.drainWallet().drainTo(script);
      } else {
        txBuilder = txBuilder.addRecipient(script, amount!);
      }

      for (final address in wallet.allFreezedAddresses())
        for (final unspendable in address.getUnspentUtxosOutpoints())
          txBuilder = txBuilder.addUnSpendable(unspendable);

      if (isManualSend) {
        txBuilder = txBuilder.manuallySelectedOnly();
        final utxos = <bdk.OutPoint>[];
        for (final address in selectedAddresses) utxos.addAll(address.getUnspentUtxosOutpoints());
        txBuilder = txBuilder.addUtxos(utxos);
      }

      txBuilder = txBuilder.feeRate(feeRate);

      if (enableRbf) txBuilder = txBuilder.enableRbf();

      final txResult = await txBuilder.finish(pubWallet);

      final txDetails = txResult.txDetails;

      final extractedTx = await txResult.psbt.extractTx();
      final outputs = await extractedTx.output();
      final outAddresses = await Future.wait(
        outputs.map((txOut) async {
          final address = await bdk.Address.fromScript(
            txOut.scriptPubkey,
            wallet.getBdkNetwork(),
          );
          return address.toString();
        }),
      );

      final tx = Transaction(
        txid: txDetails.txid,
        rbfEnabled: enableRbf,
        received: txDetails.received,
        sent: txDetails.sent,
        fee: txDetails.fee ?? 0,
        height: txDetails.confirmationTime?.height,
        timestamp: txDetails.confirmationTime?.timestamp,
        label: note,
        toAddress: address,
        outAddresses: outAddresses,
        psbt: txResult.psbt.psbtBase64,
      );
      final feeAmt = await txResult.psbt.feeAmount();
      return ((tx, feeAmt, txResult.psbt.psbtBase64), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<((Wallet, String)?, Err?)> broadcastTxWithWallet({
    required String psbt,
    required bdk.Blockchain blockchain,
    required Wallet wallet,
    required String address,
    String? note,
  }) async {
    try {
      final psb = bdk.PartiallySignedTransaction(psbtBase64: psbt);
      final tx = await psb.extractTx();

      await blockchain.broadcast(tx);
      final txid = await psb.txId();
      final newTx = Transaction(
        txid: txid,
        label: note,
        toAddress: address,
        broadcastTime: DateTime.now().millisecondsSinceEpoch,
      );

      final txs = wallet.transactions.toList();
      txs.add(newTx);
      final w = wallet.copyWith(transactions: txs);

      return ((w, txid), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<Err?> broadcastTx({
    required bdk.Transaction tx,
    required bdk.Blockchain blockchain,
  }) async {
    try {
      await blockchain.broadcast(tx);
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(Transaction?, Err?)> updateTxInputAddresses({
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
          final (addresses, err) = await mempoolAPI.getVinAddressesFromTx(txid, isTestnet);
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

  Future<(Transaction?, Err?)> updateTxOutputAddresses({
    required Transaction tx,
    required Wallet wallet,
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
          return address.toString() + ':' + value.toString();
        }),
      );

      final updated = tx.copyWith(outAddresses: outAddresses);

      return (updated, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}

// Future<(Transaction?, Err?)> updateRelatedTxLabels({
//   required Transaction tx,
//   required bdk.Wallet bdkWallet,
//   // ignore: type_annotate_public_apis
//   required String label,
//   required String address,
// }) async {
//   try {
//     late bool isRelated = false;

//     for (final element in tx.inAddresses!) {
//       if (element == address) {
//         isRelated = true;
//       }
//     }

//     for (final element in tx.outAddresses!) {
//       if (element == address) {
//         isRelated = true;
//       }
//     }

//     if (isRelated) {
//       return (tx.copyWith(label: label), null);
//     }
//     return (tx, null);
//   } catch (e) {
//     return (null, Err(e.toString()));
//   }
// }

// Future<(Transaction?, Err?)> mapOutputAddresses({
//     required Transaction tx,
//     required Wallet wallet,
//   }) async {
//     try {
//       final outputStrings = tx.outAddresses;
//       final addresses = wallet.addresses;
//       final toAddresses = wallet.toAddresses;
//       final amt = tx.getAmount();
//       final (outAddrs) = await Future.wait(
//         outputStrings!.map((output) async {
//           final myAddressesIdx =
//               addresses.indexWhere((address) => address.address == output.split(':')[0]);
//           if (myAddressesIdx != -1) return addresses.elementAtOrNull(myAddressesIdx)!;

//           final toAddressesIdx =
//               toAddresses!.indexWhere((address) => address.address == output.split(':')[0]);
//           if (toAddressesIdx != -1) return toAddresses.elementAtOrNull(toAddressesIdx)!;

//           final isChange = int.parse(output.split(':')[1]) == amt;

//           return Address(
//             address: output.split(':')[0],
//             kind: isChange ? AddressKind.change : AddressKind.external,
//             state: AddressStatus.unset,
//           );
//         }),
//       );

//       final updated = tx.copyWith(outAddrs: outAddrs);

//       return (updated, null);
//     } catch (e) {
//       return (null, Err(e.toString()));
//     }
//   }

// Future<(Wallet?, Err?)> syncWalletTxsAndAddresses({
//   required Wallet wallet,
//   required bdk.Wallet bdkWallet,
// }) async {
//   try {
//     // sync bdk wallet, import state from wallet into new native type
//     // if native type exists, only update
//     // for every new tx:
//     // check collect vins and vouts
//     // check for related addresses and inherit labels

//     final storedTxs = wallet.transactions;
//     final storedAddrs = wallet.addresses;
//     final storedToAddrs = wallet.toAddresses ?? [];
//     print('storedAddrs: $storedAddrs');
//     print('storedToAddrs: $storedToAddrs');
//     final txs = await bdkWallet.listTransactions(true);
//     // final x = bdk.TxBuilderResult();

//     if (txs.isEmpty) return (wallet, null);

//     final List<Transaction> transactions = [];
//     for (final tx in txs) {
//       final idx = storedTxs.indexWhere((t) => t.txid == tx.txid);
//       Transaction? storedTx;
//       if (idx != -1) storedTx = storedTxs.elementAtOrNull(idx);
//       if (storedTx != null) {
//         print('Tx already exists, update');
//       } else {
//         print('Tx does not exist, must be added.');
//         print('Addresses related to tx must be added and label inherited.');
//         // send txs will have the address we send to and our change both to inherit the same label
//         // recieve tx will have our deposit address
//       }

//       final txObj = Transaction(
//         txid: tx.txid,
//         received: tx.received,
//         sent: tx.sent,
//         fee: tx.fee ?? 0,
//         height: tx.confirmationTime?.height ?? 0,
//         timestamp: tx.confirmationTime?.timestamp ?? 0,
//         bdkTx: tx,
//         rbfEnabled: storedTx?.rbfEnabled ?? false,
//         // label: label,
//       );
//       const label = '';
//       final outputs = await tx.transaction?.output();
//       for (final out in outputs!) {
//         final addresss = await bdk.Address.fromScript(
//           out.scriptPubkey,
//           wallet.getBdkNetwork(),
//         );
//         final addressStr = addresss.toString();
//         print('$addressStr:${out.value}');
//       }
//       print(outputs.first.scriptPubkey);

//       print('Check to match address with transaction');

//       transactions.add(txObj.copyWith(label: label));
//     }

//     final w = wallet.copyWith(transactions: transactions);

//     return (w, null);
//   } catch (e) {
//     return (null, Err(e.toString(), expected: e.toString() == 'No bdk transactions found'));
//   }
// }
