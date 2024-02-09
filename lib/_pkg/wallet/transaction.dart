import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:hex/hex.dart';

class WalletTx {
  Transaction addOutputAddresses(Address newAddress, Transaction tx) {
    final outAddrs = List<Address>.from(tx.outAddrs);
    final index = outAddrs.indexWhere(
      (address) => address == newAddress,
    );

    if (index != -1) {
      final updatedAddress = outAddrs.removeAt(index);
      // (state: newAddress.state);
      // outAddrs[index] = newAddress;
      outAddrs.insert(index, updatedAddress.copyWith(state: newAddress.state));
    } else {
      outAddrs.add(newAddress);
      // print(outAddrs);
    }
    return tx.copyWith(outAddrs: outAddrs);
  }

  Future<(Wallet, Err?)> addUnsignedTxToWallet({
    required Transaction transaction,
    required Wallet wallet,
  }) async {
    try {
      final unsignedTxs = List<Transaction>.from(wallet.unsignedTxs);
      final index = unsignedTxs.indexWhere(
        (tx) => tx.txid == transaction.txid,
      );

      List<Transaction> updatedUnsignedTxs;

      if (index != -1) {
        updatedUnsignedTxs = wallet.unsignedTxs.map((tx) {
          return tx.txid == transaction.txid ? transaction : tx;
        }).toList();
      } else {
        updatedUnsignedTxs = List.from(wallet.unsignedTxs)..add(transaction);
      }

      final updatedWallet = wallet.copyWith(unsignedTxs: updatedUnsignedTxs);

      return (updatedWallet, null);
    } on Exception catch (e) {
      return (
        wallet,
        Err(
          e.message,
          title: 'Error occurred while adding unsigned transaction',
          solution: 'Please try again.',
        )
      ); // returning original wallet in case of error
    }
  }

  //
  // THIS NEEDS WORK
  //
  Future<(Wallet?, Err?)> getTransactions({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final storedTxs = wallet.transactions.toList();
      final unsignedTxs = wallet.unsignedTxs.toList();
      final bdkNetwork = wallet.getBdkNetwork();
      if (bdkNetwork == null) throw 'No bdkNetwork';

      final txs = await bdkWallet.listTransactions(true);
      // final x = bdk.TxBuilderResult();

      if (txs.isEmpty) return (wallet, null);

      final List<Transaction> transactions = [];

      for (final tx in txs) {
        String? label;

        final storedTxIdx = storedTxs.indexWhere((t) => t.txid == tx.txid);
        final idxUnsignedTx = unsignedTxs.indexWhere((t) => t.txid == tx.txid);

        Transaction? storedTx;
        if (storedTxIdx != -1) storedTx = storedTxs.elementAtOrNull(storedTxIdx);
        if (idxUnsignedTx != -1) {
          if (tx.txid == unsignedTxs[idxUnsignedTx].txid) unsignedTxs.removeAt(idxUnsignedTx);
        }
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
        );
        // var outAddrs;
        // var inAddres;
        final SerializedTx sTx = SerializedTx.fromJson(
          jsonDecode(txObj.bdkTx!.serializedTx!) as Map<String, dynamic>,
        );
        if (storedTxIdx != -1 &&
            storedTxs[storedTxIdx].label != null &&
            storedTxs[storedTxIdx].label!.isNotEmpty) label = storedTxs[storedTxIdx].label;

        Address? externalAddress;
        Address? changeAddress;
        Address? depositAddress;
        const hexDecoder = HexDecoder();

        if (!txObj.isReceived()) {
          //
          //
          // HANDLE EXTERNAL RECIPIENT
          //
          //
          externalAddress = wallet.getAddressFromAddresses(
            txObj.txid,
            isSend: !txObj.isReceived(),
            kind: AddressKind.external,
          );

          final amountSentToExternal = tx.sent - (tx.received + (tx.fee ?? 0));

          if (externalAddress != null) {
            if (externalAddress.label != null && externalAddress.label!.isNotEmpty)
              label = externalAddress.label;
            else
              externalAddress = externalAddress.copyWith(label: label);

            // Future.delayed(const Duration(milliseconds: 100));
          } else {
            try {
              if (sTx.output == null) throw 'No output object';
              final scriptPubkeyString = sTx.output
                  ?.firstWhere((output) => output.value == amountSentToExternal)
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

              (externalAddress, _) = await WalletAddress().addAddressToWallet(
                address: (null, addressStruct.toString()),
                wallet: wallet.copyWith(),
                spentTxId: tx.txid,
                kind: AddressKind.external,
                state: AddressStatus.used,
                spendable: false,
                label: label,
              );
              // Future.delayed(const Duration(milliseconds: 100));
            } catch (e) {
              // usually scriptpubkey not available
              // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
              // print(e);
            }
          }
          txObj = txObj.copyWith(
            toAddress: externalAddress != null ? externalAddress.address : '',
            // fromAddress: '',
          );
          if (externalAddress != null) txObj = addOutputAddresses(externalAddress, txObj);
          //
          //
          // HANDLE CHANGE
          //
          //

          changeAddress = wallet.getAddressFromAddresses(
            txObj.txid,
            isSend: !txObj.isReceived(),
            kind: AddressKind.change,
          );

          final amountChange = tx.received;

          if (changeAddress != null) {
            if (changeAddress.label != null && changeAddress.label!.isNotEmpty)
              label = changeAddress.label;
            else {
              changeAddress = changeAddress.copyWith(label: label);
            }
          } else {
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

              (changeAddress, _) = await WalletAddress().addAddressToWallet(
                address: (null, addressStruct.toString()),
                wallet: wallet,
                spentTxId: tx.txid,
                kind: AddressKind.change,
                state: AddressStatus.used,
                label: label,
              );
              // Future.delayed(const Duration(milliseconds: 100));
            } catch (e) {
              // usually scriptpubkey not available
              // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
              // print(e);
            }
          }
          if (changeAddress != null) txObj = addOutputAddresses(changeAddress, txObj);
        } else if (txObj.isReceived()) {
          depositAddress = wallet.getAddressFromAddresses(
            txObj.txid,
            isSend: !txObj.isReceived(),
            kind: AddressKind.deposit,
          );
          final amountReceived = tx.received;

          if (depositAddress != null) {
            if (depositAddress.label != null && depositAddress.label!.isNotEmpty)
              label = depositAddress.label;
            else
              depositAddress = depositAddress.copyWith(label: label);
          } else {
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
              (depositAddress, _) = await WalletAddress().addAddressToWallet(
                address: (null, addressStruct.toString()),
                wallet: wallet,
                spentTxId: tx.txid,
                kind: AddressKind.deposit,
                state: AddressStatus.used,
                spendable: false,
                label: label,
              );
              // Future.delayed(const Duration(milliseconds: 100));
            } catch (e) {
              // usually scriptpubkey not available
              // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
              // print(e);
            }
          }
          txObj = txObj.copyWith(
            toAddress: depositAddress != null ? depositAddress.address : '',
            // fromAddress: '',
          );
          if (depositAddress != null) {
            final txObj2 = addOutputAddresses(depositAddress, txObj);
            txObj = txObj2.copyWith(outAddrs: txObj2.outAddrs);
          }
        }

        if (storedTxIdx != -1 &&
            storedTxs[storedTxIdx].label != null &&
            storedTxs[storedTxIdx].label!.isNotEmpty) label = storedTxs[storedTxIdx].label;

        transactions.add(txObj.copyWith(label: label));
        // Future.delayed(const Duration(milliseconds: 100));
      }

      // Future.delayed(const Duration(milliseconds: 200));
      final w = wallet.copyWith(
        transactions: transactions,
        unsignedTxs: unsignedTxs,
      );

      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while getting transactions',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(Wallet?, Err?)> getTransactionsNew({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final storedTxs = wallet.transactions;
      final unsignedTxs = wallet.unsignedTxs;
      final bdkNetwork = wallet.getBdkNetwork();
      if (bdkNetwork == null) throw 'No bdkNetwork';

      final txs = await bdkWallet.listTransactions(true);
      // final x = bdk.TxBuilderResult();

      if (txs.isEmpty) return (wallet, null);

      final List<Transaction> transactions = [];

      for (final tx in txs) {
        String? label;

        final storedTxIdx = storedTxs.indexWhere((t) => t.txid == tx.txid);
        final idxUnsignedTx = unsignedTxs.indexWhere((t) => t.txid == tx.txid);

        Transaction? storedTx;
        if (storedTxIdx != -1) storedTx = storedTxs.elementAtOrNull(storedTxIdx);
        if (idxUnsignedTx != -1) {
          if (tx.txid == unsignedTxs[idxUnsignedTx].txid) unsignedTxs.removeAt(idxUnsignedTx);
        }
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
        );

        if (storedTxIdx != -1 &&
            storedTxs[storedTxIdx].label != null &&
            storedTxs[storedTxIdx].label!.isNotEmpty) label = storedTxs[storedTxIdx].label;

        final SerializedTx sTx = SerializedTx.fromJson(
          jsonDecode(txObj.bdkTx!.serializedTx!) as Map<String, dynamic>,
        );

        const hexDecoder = HexDecoder();
        final outputs = sTx.output;

        for (final output in outputs!) {
          final scriptPubKey = await bdk.Script.create(
            hexDecoder.convert(output.scriptPubkey!) as Uint8List,
          );

          final addressStruct = await bdk.Address.fromScript(
            scriptPubKey,
            bdkNetwork,
          );

          final existing = wallet.findAddressInWallet(addressStruct.toString());
          if (existing != null) {
            // txObj.outAddrs.add(existing);
            if (existing.label == null && existing.label!.isEmpty)
              txObj = addOutputAddresses(existing.copyWith(label: label), txObj);
            else {
              label ??= existing.label;
              txObj = addOutputAddresses(existing, txObj);
            }
          } else {
            if (txObj.isReceived()) {
              // AddressKind.deposit should exist in the addressBook
              // may not be applicable for payjoin
            } else {
              // AddressKind.external wont exist for imported wallets and must be added here
              // AddressKind.change should exist in the addressBook
              final (externalAddress, _) = await WalletAddress().addAddressToWallet(
                address: (null, addressStruct.toString()),
                wallet: wallet,
                spentTxId: tx.txid,
                kind: AddressKind.external,
                state: AddressStatus.used,
                spendable: false,
                label: label,
              );
              txObj = addOutputAddresses(externalAddress, txObj);
            }
          }
        }

        if (txObj.isReceived()) {
          final recipients = txObj.outAddrs
              .where((element) => element.kind == AddressKind.deposit)
              .toList()
              .map((e) => e.address);
          // may break for payjoin

          txObj = txObj.copyWith(
            toAddress: recipients.toString(),
          );
        } else {
          final recipients = txObj.outAddrs
              .where((element) => element.kind == AddressKind.external)
              .toList()
              .map((e) => e.address);
          txObj = txObj.copyWith(
            toAddress: recipients.toString(),
          );
        }

        transactions.add(txObj.copyWith(label: label));
      }

      final w = wallet.copyWith(
        transactions: transactions,
        unsignedTxs: unsignedTxs,
      );

      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while getting transactions',
          solution: 'Please try again.',
        )
      );
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
      final isMainnet = wallet.network == BBNetwork.Mainnet;
      if (isMainnet != isMainnetAddress(address)) {
        return (
          null,
          Err('Invalid Address. Network Mismatch!'),
        );
      }
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

      final bdkNetwork = wallet.getBdkNetwork();
      if (bdkNetwork == null) throw 'No bdkNetwork';

      final outAddrsFutures = outputs.map((txOut) async {
        final scriptAddress = await bdk.Address.fromScript(
          txOut.scriptPubkey,
          bdkNetwork,
        );
        if (txOut.value == amount! && !sendAllCoin && scriptAddress.toString() == address) {
          return Address(
            address: scriptAddress.toString(),
            kind: AddressKind.external,
            state: AddressStatus.used,
            highestPreviousBalance: amount,
            label: note ?? '',
            spendable: false,
          );
        } else {
          return Address(
            address: scriptAddress.toString(),
            kind: AddressKind.change,
            state: AddressStatus.used,
            highestPreviousBalance: txOut.value,
            label: note ?? '',
          );
        }
      });

      final List<Address> outAddrs = await Future.wait(outAddrsFutures);
      final feeAmt = await txResult.psbt.feeAmount();

      final Transaction tx = Transaction(
        txid: txDetails.txid,
        rbfEnabled: enableRbf,
        received: txDetails.received,
        sent: txDetails.sent,
        fee: feeAmt ?? 0,
        height: txDetails.confirmationTime?.height,
        timestamp: txDetails.confirmationTime?.timestamp ?? 0,
        label: note,
        toAddress: address,
        outAddrs: outAddrs,
        psbt: txResult.psbt.psbtBase64,
      );
      return ((tx, feeAmt, txResult.psbt.psbtBase64), null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while building transaction',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(bdk.Transaction?, Err?)> finalizeTx({
    required String psbt,
    // required bdk.Blockchain blockchain,
    required bdk.Wallet bdkWallet,
    // required String address,
  }) async {
    try {
      final psbtStruct = bdk.PartiallySignedTransaction(psbtBase64: psbt);
      // final tx = await psbtStruct.extractTx();
      final finalized = await bdkWallet.sign(
        psbt: psbtStruct,
        signOptions: const bdk.SignOptions(
          isMultiSig: false,
          trustWitnessUtxo: false,
          allowAllSighashes: false,
          removePartialSigs: true,
          tryFinalize: true,
          signWithTapInternalKey: false,
          allowGrinding: true,
        ),
      );
      final extracted = await finalized.extractTx();

      return (extracted, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while signing transaction',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<((Wallet, String)?, Err?)> broadcastTxWithWallet({
    required String psbt,
    required bdk.Blockchain blockchain,
    required Wallet wallet,
    required String address,
    required Transaction transaction,
    String? note,
  }) async {
    try {
      final psbtStruct = bdk.PartiallySignedTransaction(psbtBase64: psbt);
      final tx = await psbtStruct.extractTx();

      await blockchain.broadcast(tx);
      final txid = await psbtStruct.txId();
      final newTx = transaction.copyWith(
        txid: txid,
        label: note,
        toAddress: address,
        broadcastTime: DateTime.now().millisecondsSinceEpoch,
        oldTx: false,
      );

      final txs = wallet.transactions.toList();
      // final txs = walletBloc.state.wallet!.transactions.toList();
      final idx = txs.indexWhere((element) => element.txid == newTx.txid);
      if (idx != -1) {
        txs.removeAt(idx);
        txs.insert(idx, newTx);
      } else
        txs.add(newTx);
      // txs.add(newTx);
      final w = wallet.copyWith(transactions: txs);

      return ((w, txid), null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while broadcasting transaction',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<Err?> broadcastTx({
    required bdk.Transaction tx,
    required bdk.Blockchain blockchain,
  }) async {
    try {
      await blockchain.broadcast(tx);
      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while broadcasting transaction',
        solution: 'Please try again.',
      );
    }
  }
}
