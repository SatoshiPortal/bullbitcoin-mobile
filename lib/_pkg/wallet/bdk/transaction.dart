import 'dart:convert';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:convert/convert.dart' as conv;

class BDKTransactions {
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

  Future<(Wallet, Err?)> addSwapTxToWallet({
    required SwapTx swapTx,
    required Wallet wallet,
  }) async {
    try {
      final swaps = List<SwapTx>.from(wallet.swaps);
      final index = swaps.indexWhere(
        (swap) => swap.id == swapTx.id,
      );

      List<SwapTx> updatedSwaps;

      if (index != -1) {
        updatedSwaps = wallet.swaps.map((swap) {
          return swap.id == swapTx.id ? swapTx : swap;
        }).toList();
      } else {
        updatedSwaps = List.from(wallet.swaps)..add(swapTx);
      }

      final updatedWallet = wallet.copyWith(swaps: updatedSwaps);

      return (updatedWallet, null);
    } on Exception catch (e) {
      return (
        wallet,
        Err(
          e.message,
          title: 'Error occurred while adding swap transaction',
          solution: 'Please try again.',
        )
      ); // returning original wallet in case of error
    }
  }

  /// If given swap is expired,
  ///   - check if the swapTx has been refunded
  ///   - If yes, remove it from wallet.swaps
  ///   - if not, add it to the list of swaps to refund and return
  /// If not,
  ///   - update txid of wallet.swaps with swapTx.txid
  (({Wallet wallet})?, Err?) updateSwapTxs({
    required SwapTx swapTx,
    required Wallet wallet,
  }) {
    final swaps = wallet.swaps;

    final idx = swaps.indexWhere((_) => _.id == swapTx.id);
    if (idx == -1) return (null, Err('No swapTx found'));

    final storedSwap = swaps[idx];

    final swapTxs = List<SwapTx>.from(swaps);

    final updatedSwapTx = storedSwap.copyWith(
      status: swapTx.status,
      txid: storedSwap.txid ?? swapTx.txid,
      lnSwapDetails: storedSwap.lnSwapDetails!.copyWith(
        keyIndex: storedSwap.lnSwapDetails!.keyIndex,
      ),
    );
    swapTxs[idx] = updatedSwapTx;

    final swapsToDelete = <SwapTx>[
      for (final s in swapTxs)
        if (s.paidSubmarine() ||
            s.settledReverse() ||
            s.settledSubmarine() ||
            s.expiredReverse())
          s,
    ];

    for (final s in swapsToDelete)
      if (swapsToDelete.any((_) => _.id == s.id))
        swapTxs.removeWhere((_) => _.id == s.id);

    final updatedWallet = wallet.copyWith(swaps: swapTxs);

    return ((wallet: updatedWallet), null);
  }

  Future<(({Wallet wallet, SwapTx swapsToDelete})?, Err?)> mergeSwapTxIntoTx({
    required Wallet wallet,
    required SwapTx swapTx,
  }) async {
    try {
      final txs = wallet.transactions.toList();
      final swaps = wallet.swaps;
      final updatedSwaps = swaps.toList();
      // final swapsToDelete = <SwapTx>[];

      final idx = txs.indexWhere((_) => _.txid == swapTx.txid);
      if (idx == -1) return (null, Err('No new matching tx'));

      final newTx = txs[idx].copyWith(
        swapTx: swapTx,
        isSwap: true,
        label: swapTx.label,
      );
      txs[idx] = newTx;

      final swapToDelete = swaps.firstWhere((_) => _.id == swapTx.id);
      // swapsToDelete.add(swapToDelete);
      updatedSwaps.removeWhere((_) => _.id == swapTx.id);

      final updatedWallet = wallet.copyWith(
        transactions: txs,
        swaps: updatedSwaps,
      );

      return ((wallet: updatedWallet, swapsToDelete: swapToDelete), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  //
  // THIS NEEDS WORK
  //
  Future<(Wallet?, Err?)> getTransactions({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
    required WalletAddress walletAddress,
  }) async {
    try {
      final storedTxs = wallet.transactions.toList();
      final unsignedTxs = wallet.unsignedTxs.toList();
      final bdkNetwork = wallet.getBdkNetwork();
      if (bdkNetwork == null) throw 'No bdkNetwork';

      final txs = await bdkWallet.listTransactions(includeRaw: true);
      // final x = bdk.TxBuilderResult();

      if (txs.isEmpty) return (wallet, null);

      final List<Transaction> transactions = [];

      for (final tx in txs) {
        String? label;

        final storedTxIdx = storedTxs.indexWhere((t) => t.txid == tx.txid);
        final idxUnsignedTx = unsignedTxs.indexWhere((t) => t.txid == tx.txid);

        Transaction? storedTx;
        if (storedTxIdx != -1)
          storedTx = storedTxs.elementAtOrNull(storedTxIdx);

        final vsize = await tx.transaction?.vsize() ?? 1;
        final isNativeRbf = storedTx?.rbfEnabled ?? true;
        //  await tx.transaction?.isExplicitlyRbf() ??

        final SerializedTx sTx = SerializedTx.fromJson(
          jsonDecode(tx.transaction!.inner) as Map<String, dynamic>,
        );
        final inputs = storedTx?.inputs ??
            sTx.input
                ?.map(
                  (e) => TxIn(
                    prevOut: e.previousOutput ?? '',
                  ),
                )
                .toList() ??
            [];
        var txObj = Transaction(
          txid: tx.txid,
          received: tx.received,
          sent: tx.sent,
          fee: tx.fee ?? 0,
          feeRate: (tx.fee ?? 1) / vsize.toDouble(),
          height: tx.confirmationTime?.height ?? 0,
          timestamp: tx.confirmationTime?.timestamp ?? 0,
          bdkTx: tx,
          // rbfEnabled: storedTx?.rbfEnabled ?? isNativeRbf,
          rbfEnabled: isNativeRbf,
          outAddrs: storedTx?.outAddrs ?? [],
          inputs: inputs,
          swapTx: storedTx?.swapTx,
          isSwap: storedTx?.isSwap ?? false,
          rbfTxIds: storedTx?.rbfTxIds ?? [],
        );
        if (storedTxIdx != -1 &&
            storedTxs[storedTxIdx].label != null &&
            storedTxs[storedTxIdx].label!.isNotEmpty)
          label = storedTxs[storedTxIdx].label;

        Address? externalAddress;
        Address? changeAddress;
        Address? depositAddress;
        // const hexDecoder = HexDecoder();

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
            if (externalAddress.label != null &&
                externalAddress.label!.isNotEmpty)
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

              final scriptPubKey = await bdk.ScriptBuf.fromHex(
                scriptPubkeyString,
              );

              final addressStruct = await bdk.Address.fromScript(
                script: scriptPubKey,
                network: bdkNetwork,
              );
              final addressStr = await addressStruct.asString();

              (externalAddress, _) = await walletAddress.addAddressToWallet(
                address: (null, addressStr),
                wallet: wallet,
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
          if (externalAddress != null)
            txObj = addOutputAddresses(externalAddress, txObj);
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
              final scriptPubkeyString = sTx.output
                  ?.firstWhere((output) => output.value == amountChange)
                  .scriptPubkey;

              if (scriptPubkeyString == null) {
                throw 'No script pubkey';
              }

              final scriptPubKey = await bdk.ScriptBuf.fromHex(
                scriptPubkeyString,
              );

              final addressStruct = await bdk.Address.fromScript(
                script: scriptPubKey,
                network: bdkNetwork,
              );
              final addressStr = await addressStruct.asString();

              (changeAddress, _) = await walletAddress.addAddressToWallet(
                address: (null, addressStr),
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
          if (changeAddress != null)
            txObj = addOutputAddresses(changeAddress, txObj);
        } else if (txObj.isReceived()) {
          depositAddress = wallet.getAddressFromAddresses(
            txObj.txid,
            isSend: !txObj.isReceived(),
            kind: AddressKind.deposit,
          );
          final amountReceived = tx.received;

          if (depositAddress != null) {
            if (depositAddress.label != null &&
                depositAddress.label!.isNotEmpty)
              label = depositAddress.label;
            else
              depositAddress = depositAddress.copyWith(label: label);
          } else {
            try {
              if (sTx.output == null) throw 'No output object';
              final scriptPubkeyString = sTx.output
                  ?.firstWhere((output) => output.value == amountReceived)
                  .scriptPubkey;

              if (scriptPubkeyString == null) {
                throw 'No script pubkey';
              }

              final scriptPubKey = await bdk.ScriptBuf.fromHex(
                scriptPubkeyString,
              );
              final addressStruct = await bdk.Address.fromScript(
                script: scriptPubKey,
                network: bdkNetwork,
              );
              final addressStr = await addressStruct.asString();

              (depositAddress, _) = await walletAddress.addAddressToWallet(
                address: (null, addressStr),
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
            storedTxs[storedTxIdx].label!.isNotEmpty)
          label = storedTxs[storedTxIdx].label;

        if (idxUnsignedTx != -1) {
          if (tx.txid == unsignedTxs[idxUnsignedTx].txid) {
            final usTx = unsignedTxs.removeAt(idxUnsignedTx);
            transactions.add(
              txObj.copyWith(
                label: usTx.label,
                outAddrs: usTx.outAddrs,
              ),
            );
          } else
            transactions.add(txObj.copyWith(label: label));
        } else
          transactions.add(txObj.copyWith(label: label));
        // Future.delayed(const Duration(milliseconds: 100));
      }

      final List<Transaction> pendingTxs = [];
      final List<List<bdk.TxIn>> pendingTxInputs = [];
      for (final tx in transactions) {
        if (tx.isPending() && tx.isReceived()) {
          pendingTxs.add(tx);
          final ip = await tx.bdkTx?.transaction?.input() ?? [];
          pendingTxInputs.add(ip);
        }
      }

      // Future.delayed(const Duration(milliseconds: 200));

      for (final tx in storedTxs) {
        if (transactions.any((t) => t.txid == tx.txid)) continue;

        // This check is to eliminate sent RBF duplicates
        if (transactions.any((t) {
          return t.rbfTxIds.any((ids) => ids == tx.txid);
        })) continue;

        // TODO: Merged above two into single iteration;
        //if (transactions.any((t) =>
        //    t.txid == tx.txid || t.rbfTxIds.any((ids) => ids == tx.txid)))
        //  continue;

        // This check is to eliminate receive RBF duplicates
        if (isReceiveRBFParent(tx, pendingTxInputs)) {
          print('${tx.txid} is RBF parent of a receive tx');
          continue;
        }

        transactions.add(tx);
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

  // bool isRBFTx(
  //   List<Transaction> txlist,
  //   Transaction tx,
  // ) {

  //   for (final Transactiontx in txlist) {
  //     final rbfMatch = tx.txid
  //   }
  //
  // }

  /*
  Future<bool> isRBFTx(
    bdk.Network bdkNetwork,
    List<bdk.TransactionDetails> pending,
    Transaction tx,
  ) async {
    for (final Address addr in tx.outAddrs) {
      for (final bdk.TransactionDetails pendingTx in pending) {
        //print(
        //  '[stored] ${tx.txid} ${tx.sent}/${tx.received} ${tx.fee} ${tx.outAddrs.length}:${addr.address}',
        //);

        final SerializedTx sTx = SerializedTx.fromJson(
          jsonDecode(pendingTx.transaction!.inner) as Map<String, dynamic>,
        );
        final outs = sTx.output;
        for (final Output out in sTx.output ?? []) {
          final scriptPubKey = await bdk.ScriptBuf.fromHex(
            out.scriptPubkey ?? '',
          );
          final addressStruct = await bdk.Address.fromScript(
            script: scriptPubKey,
            network: bdkNetwork,
          );
          final addressStr = await addressStruct.asString();

          final pendingTxId = await pendingTx.transaction?.txid();
          // print(
          //   '${tx.txid} ${tx.sent}/${tx.received} ${tx.fee} ${sTx.output?.length}:$addressStr',
          // );

          // TODO:
          // 1. In transaction model, have array of txid for storing past RBF txs
          if (addressStr == addr.address) {
            print('$pendingTxId is RBF of ${tx.txid}');
            return true;
          }
        }
      }
    }
    return false;
  }
  */

  // Future<(Wallet?, Err?)> getTransactionsNew({
  //   required Wallet wallet,
  //   required bdk.Wallet bdkWallet,
  // }) async {
  //   try {
  //     final storedTxs = wallet.transactions;
  //     final unsignedTxs = wallet.unsignedTxs;
  //     final bdkNetwork = wallet.getBdkNetwork();
  //     if (bdkNetwork == null) throw 'No bdkNetwork';

  //     final txs = await bdkWallet.listTransactions(true);
  //     // final x = bdk.TxBuilderResult();

  //     if (txs.isEmpty) return (wallet, null);

  //     final List<Transaction> transactions = [];

  //     for (final tx in txs) {
  //       String? label;

  //       final storedTxIdx = storedTxs.indexWhere((t) => t.txid == tx.txid);
  //       final idxUnsignedTx = unsignedTxs.indexWhere((t) => t.txid == tx.txid);

  //       Transaction? storedTx;
  //       if (storedTxIdx != -1) storedTx = storedTxs.elementAtOrNull(storedTxIdx);
  //       if (idxUnsignedTx != -1) {
  //         if (tx.txid == unsignedTxs[idxUnsignedTx].txid) unsignedTxs.removeAt(idxUnsignedTx);
  //       }
  //       var txObj = Transaction(
  //         txid: tx.txid,
  //         received: tx.received,
  //         sent: tx.sent,
  //         fee: tx.fee ?? 0,
  //         height: tx.confirmationTime?.height ?? 0,
  //         timestamp: tx.confirmationTime?.timestamp ?? 0,
  //         bdkTx: tx,
  //         rbfEnabled: storedTx?.rbfEnabled ?? false,
  //         outAddrs: storedTx?.outAddrs ?? [],
  //       );

  //       if (storedTxIdx != -1 &&
  //           storedTxs[storedTxIdx].label != null &&
  //           storedTxs[storedTxIdx].label!.isNotEmpty) label = storedTxs[storedTxIdx].label;

  //       final SerializedTx sTx = SerializedTx.fromJson(
  //         jsonDecode(txObj.bdkTx!.serializedTx!) as Map<String, dynamic>,
  //       );

  //       const hexDecoder = HexDecoder();
  //       final outputs = sTx.output;

  //       for (final output in outputs!) {
  //         final scriptPubKey = await bdk.Script.create(
  //           hexDecoder.convert(output.scriptPubkey!) as Uint8List,
  //         );

  //         final addressStruct = await bdk.Address.fromScript(
  //           scriptPubKey,
  //           bdkNetwork,
  //         );

  //         final existing = wallet.findAddressInWallet(addressStruct.toString());
  //         if (existing != null) {
  //           // txObj.outAddrs.add(existing);
  //           if (existing.label == null && existing.label!.isEmpty)
  //             txObj = addOutputAddresses(existing.copyWith(label: label), txObj);
  //           else {
  //             label ??= existing.label;
  //             txObj = addOutputAddresses(existing, txObj);
  //           }
  //         } else {
  //           if (txObj.isReceived()) {
  //             // AddressKind.deposit should exist in the addressBook
  //             // may not be applicable for payjoin
  //           } else {
  //             // AddressKind.external wont exist for imported wallets and must be added here
  //             // AddressKind.change should exist in the addressBook
  //             final (externalAddress, _) = await WalletAddress().addAddressToWallet(
  //               address: (null, addressStruct.toString()),
  //               wallet: wallet,
  //               spentTxId: tx.txid,
  //               kind: AddressKind.external,
  //               state: AddressStatus.used,
  //               spendable: false,
  //               label: label,
  //             );
  //             txObj = addOutputAddresses(externalAddress, txObj);
  //           }
  //         }
  //       }

  //       if (txObj.isReceived()) {
  //         final recipients = txObj.outAddrs
  //             .where((element) => element.kind == AddressKind.deposit)
  //             .toList()
  //             .map((e) => e.address);
  //         // may break for payjoin

  //         txObj = txObj.copyWith(
  //           toAddress: recipients.toString(),
  //         );
  //       } else {
  //         final recipients = txObj.outAddrs
  //             .where((element) => element.kind == AddressKind.external)
  //             .toList()
  //             .map((e) => e.address);
  //         txObj = txObj.copyWith(
  //           toAddress: recipients.toString(),
  //         );
  //       }

  //       transactions.add(txObj.copyWith(label: label));
  //     }

  //     final w = wallet.copyWith(
  //       transactions: transactions,
  //       unsignedTxs: unsignedTxs,
  //     );

  //     return (w, null);
  //   } on Exception catch (e) {
  //     return (
  //       null,
  //       Err(
  //         e.message,
  //         title: 'Error occurred while getting transactions',
  //         solution: 'Please try again.',
  //       )
  //     );
  //   }
  // }

  Future<((Transaction?, int?, String)?, Err?)> buildTx({
    required Wallet wallet,
    required bdk.Wallet pubWallet,
    required bool isManualSend,
    required String address,
    required int? amount,
    required bool sendAllCoin,
    required double feeRate,
    required bool enableRbf,
    required List<UTXO> selectedUtxos,
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
      final bdkAddress = await bdk.Address.fromString(
        s: address,
        network: wallet.getBdkNetwork()!,
      );
      final script = await bdkAddress.scriptPubkey();
      if (sendAllCoin) {
        txBuilder = txBuilder.drainWallet().drainTo(script);
      } else {
        txBuilder = txBuilder.addRecipient(script, amount!);
      }

      for (final address in wallet.allFreezedAddresses())
        for (final unspendable
            in address.getUnspentUtxosOutpoints(wallet.utxos))
          txBuilder = txBuilder.addUnSpendable(unspendable);

      if (isManualSend) {
        txBuilder = txBuilder.manuallySelectedOnly();
        final List<bdk.OutPoint> utxos = selectedUtxos.map((e) {
          return bdk.OutPoint(txid: e.txid, vout: e.txIndex);
        }).toList();
        /*
        for (final address in selectedUtxos)
          utxos.addAll(address.getUnspentUtxosOutpoints(wallet.utxos));
          */
        txBuilder = txBuilder.addUtxos(utxos);
      }

      txBuilder = txBuilder.feeRate(feeRate);

      if (enableRbf) txBuilder = txBuilder.enableRbf();

      final txResult = await txBuilder.finish(pubWallet);

      final psbt = txResult.$1;
      final txDetails = txResult.$2;

      final extractedTx = await psbt.extractTx();
      final outputs = await extractedTx.output();
      final inputs = await extractedTx.input();

      final bdkNetwork = wallet.getBdkNetwork();
      if (bdkNetwork == null) throw 'No bdkNetwork';

      final outAddrsFutures = outputs.map((txOut) async {
        final scriptAddress = await bdk.Address.fromScript(
          script: bdk.ScriptBuf(bytes: txOut.scriptPubkey.bytes),
          network: bdkNetwork,
        );
        final addressStr = await scriptAddress.asString();
        if (txOut.value == amount! && !sendAllCoin && addressStr == address) {
          return Address(
            address: addressStr,
            kind: AddressKind.external,
            state: AddressStatus.used,
            highestPreviousBalance: amount,
            balance: amount,
            label: note ?? '',
            spendable: false,
          );
        } else {
          return Address(
            address: addressStr,
            kind: AddressKind.change,
            state: AddressStatus.used,
            highestPreviousBalance: txOut.value,
            balance: txOut.value,
            label: note ?? '',
          );
        }
      });
      final List<String> labels = [];
      final inAddrsFutures = inputs.map((txIn) async {
        final txid = txIn.previousOutput.txid;
        final vout = txIn.previousOutput.vout;
        try {
          final input = wallet.utxos.firstWhere(
            (utxo) =>
                utxo.txid == txid && utxo.txIndex == vout && utxo.label != '',
          );
          labels.add(input.label);
        } catch (e) {
          print('no matching input with label');
        }
      });
      await Future.wait(inAddrsFutures);
      final List<Address> outAddrs = await Future.wait(outAddrsFutures);
      final feeAmt = await txResult.$1.feeAmount();
      final psbtStr = await psbt.serialize();
      // if (note != null || note != '') labels.add(note!);
      final labelsString = labels.isNotEmpty ? labels.last : '';

      final Transaction tx = Transaction(
        txid: txDetails.txid,
        rbfEnabled: enableRbf,
        received: txDetails.received,
        sent: txDetails.sent,
        fee: feeAmt ?? 0,
        feeRate: feeRate,
        height: txDetails.confirmationTime?.height,
        timestamp: 0,
        // txDetails.confirmationTime?.timestamp ?? 0,
        label: (note == null || note == '')
            ? labelsString
            : note, // for now we just take the first label
        toAddress: address,
        outAddrs: outAddrs,
        psbt: psbtStr,
      );
      return ((tx, feeAmt, psbtStr), null);
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

  // Future<(String?, Err?)> signTx({
  //   required String unsignedPSBT,
  //   required bdk.Wallet signingWallet,
  // }) async {
  //   try {
  //     final psbt = bdk.PartiallySignedTransaction(psbtBase64: unsignedPSBT);
  //     final signedPSBT = await signingWallet.sign(psbt: psbt);
  //     return (signedPSBT.psbtBase64, null);
  //   } on Exception catch (e) {
  //     return (
  //       null,
  //       Err(
  //         e.message,
  //         title: 'Error occurred while signing transaction',
  //         solution: 'Please try again.',
  //       )
  //     );
  //   }
  // }

  Future<((bdk.Transaction, String)?, Err?)> signTx({
    required String psbt,
    // required bdk.Blockchain blockchain,
    required bdk.Wallet bdkWallet,
    // required String address,
  }) async {
    try {
      final psbtStruct = await bdk.PartiallySignedTransaction.fromString(psbt);
      final tx = await psbtStruct.extractTx();
      final _ = await bdkWallet.sign(
        psbt: psbtStruct,
        signOptions: const bdk.SignOptions(
          // multiSig: false,
          trustWitnessUtxo: false,
          allowAllSighashes: false,
          removePartialSigs: true,
          tryFinalize: true,
          signWithTapInternalKey: false,
          allowGrinding: true,
        ),
      );
      // final extracted = await finalized;
      final psbtStr = await psbtStruct.serialize();

      return ((tx, psbtStr), null);
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
    int vsize = 0;
    try {
      final psbtStruct = await bdk.PartiallySignedTransaction.fromString(psbt);
      final tx = await psbtStruct.extractTx();
      vsize = await tx.vsize();

      await blockchain.broadcast(transaction: tx);
      final txid = await psbtStruct.txid();
      final newTx = transaction.copyWith(
        txid: txid,
        label: note,
        toAddress: address,
        broadcastTime: DateTime.now().millisecondsSinceEpoch,
        // oldTx: false,
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
      final errMsg = e.message;
      if (errMsg.contains('BdkError.electrum') && errMsg.contains('-26,')) {
        return (
          null,
          handleFeesTooLowError(
            vsize: vsize,
            errMsg: errMsg,
          )
        );
      }

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
      await blockchain.broadcast(transaction: tx);
      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while broadcasting transaction',
        solution: 'Please try again.',
      );
    }
  }

  Future<(bdk.Transaction?, Err?)> extractTx({required String tx}) async {
    try {
      var isPsbt = false;
      try {
        conv.hex.decode(tx);
      } catch (e) {
        isPsbt = true;
      }

      if (isPsbt) {
        final psbt = await bdk.PartiallySignedTransaction.fromString(tx);
        final bdk.Transaction bdkTx = await psbt.extractTx();
        return (bdkTx, null);
      }

      final bdkTx = await bdk.Transaction.fromBytes(
        transactionBytes: conv.hex.decode(tx),
      );

      return (bdkTx, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while broadcasting transaction',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(Transaction?, Err?)> buildBumpFeeTx({
    required Transaction tx,
    required double feeRate,
    required bdk.Wallet signingWallet,
    required bdk.Wallet pubWallet,
  }) async {
    try {
      var txBuilder = bdk.BumpFeeTxBuilder(
        txid: tx.txid,
        feeRate: feeRate,
      );
      txBuilder = txBuilder.enableRbf();
      final txResult = await txBuilder.finish(pubWallet);
      final signedPSBT = await signingWallet.sign(psbt: txResult.$1);

      final psbt = txResult.$1;
      final txDetails = txResult.$2;

      final psbtStr = await psbt.serialize();

      final newTx = Transaction(
        txid: txDetails.txid,
        received: txDetails.received,
        sent: txDetails.sent,
        fee: txDetails.fee ?? 0,
        feeRate: feeRate,
        height: txDetails.confirmationTime?.height,
        timestamp: txDetails.confirmationTime?.timestamp ?? 0,
        label: tx.label,
        toAddress: tx.toAddress,
        psbt: psbtStr,
        rbfTxIds: [...tx.rbfTxIds, tx.txid],
      );
      return (newTx, null);
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

  Err handleFeesTooLowError({
    required int vsize,
    required String errMsg,
  }) {
    final splits = errMsg.split('<');
    if (splits.length >= 2) {
      final requiredSatsStr = splits.last;
      if (requiredSatsStr.length >= 12) {
        final requiredSats = double.tryParse(requiredSatsStr.substring(0, 11));
        if (requiredSats != null) {
          final feeRate = ((requiredSats * 100000000) / vsize).ceil();

          return Err(
            'Min required: $feeRate sats/vB',
            title: 'Increase fee rate',
            solution: '',
          );
        }
      }
    }

    return Err(
      errMsg,
      title: 'Error occurred while broadcasting transaction',
      solution: 'Please try again.',
    );
  }

  bool isReceiveRBFParent(
    Transaction tx,
    List<List<bdk.TxIn>> pendingTxInputs,
  ) {
    if (tx.inputs.isEmpty) return false;
    for (final pendingTxIp in pendingTxInputs) {
      // if (pendingTxIp.length != tx.inputs.length) {
      //   // return false if inputs lengths of both txs doesn't match
      //   return false;
      // }
      // if not, check if each input.prevOut matches
      int index = 0;
      int matchingInputs = 0;
      for (final ip in pendingTxIp) {
        final pOut = '${ip.previousOutput.txid}:${ip.previousOutput.vout}';
        if (pOut == tx.inputs[index].prevOut) {
          matchingInputs++;
        }
        index++;
      }

      if (matchingInputs > 0) {
        return true;
      }
    }
    return false;
  }
}
