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
      outAddrs.insert(index, updatedAddress.copyWith(state: newAddress.state));
    } else {
      outAddrs.add(newAddress);
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

      final bdkTxs = bdkWallet.listTransactions(includeRaw: true);
      // final x = bdk.TxBuilderResult();

      if (bdkTxs.isEmpty) return (wallet, null);

      final List<Transaction> transactions = [];

      for (final bdkTx in bdkTxs) {
        String? label;
        Transaction? storedTx;

        final storedTxIdx = storedTxs.indexWhere((t) => t.txid == bdkTx.txid);
        final idxUnsignedTx =
            unsignedTxs.indexWhere((t) => t.txid == bdkTx.txid);
        final foundStoredTx = storedTxIdx != -1;
        final foundStoredUTx = idxUnsignedTx != -1;

        if (foundStoredTx) storedTx = storedTxs.elementAtOrNull(storedTxIdx);

        final vsize = await bdkTx.transaction?.vsize() ?? BigInt.from(1);
        final isNativeRbf = storedTx?.rbfEnabled ?? true;
        //  await tx.transaction?.isExplicitlyRbf() ??

        final SerializedTx serdBdkTx = SerializedTx.fromJson(
          jsonDecode(bdkTx.transaction!.s) as Map<String, dynamic>,
        );
        final inputs = storedTx?.inputs ??
            serdBdkTx.input
                ?.map(
                  (e) => TxIn(
                    prevOut: e.previousOutput ?? '',
                  ),
                )
                .toList() ??
            [];
        var updatedTx = Transaction(
          txid: bdkTx.txid,
          received: bdkTx.received.toInt(),
          sent: bdkTx.sent.toInt(),
          fee: bdkTx.fee?.toInt() ?? 0,
          feeRate: (bdkTx.fee ?? BigInt.from(1)) / vsize,
          height: bdkTx.confirmationTime?.height ?? 0,
          timestamp: bdkTx.confirmationTime?.timestamp.toInt() ?? 0,
          bdkTx: bdkTx,
          // rbfEnabled: storedTx?.rbfEnabled ?? isNativeRbf,
          rbfEnabled: isNativeRbf,
          outAddrs: storedTx?.outAddrs ?? [],
          inputs: inputs,
          swapTx: storedTx?.swapTx,
          isSwap: storedTx?.isSwap ?? false,
          rbfTxIds: storedTx?.rbfTxIds ?? [],
        );

        final storedTxHasLabel = foundStoredTx &&
            storedTxs[storedTxIdx].label != null &&
            storedTxs[storedTxIdx].label!.isNotEmpty;

        if (storedTxHasLabel) label = storedTxs[storedTxIdx].label;

        Address? externalAddress;
        Address? changeAddress;
        Address? depositAddress;
        // const hexDecoder = HexDecoder();

        if (!updatedTx.isReceived()) {
          //
          //
          // HANDLE EXTERNAL RECIPIENT
          //
          //
          externalAddress = wallet.getAddressFromAddresses(
            updatedTx.txid,
            isSend: !updatedTx.isReceived(),
            kind: AddressKind.external,
          );

          final amountSentToExternal = bdkTx.sent -
              (bdkTx.received + BigInt.from(bdkTx.fee?.toInt() ?? 0));

          if (externalAddress != null) {
            final extAddressHasLabel = externalAddress.label != null &&
                externalAddress.label!.isNotEmpty;
            if (extAddressHasLabel) {
              label = externalAddress.label;
            } else {
              externalAddress = externalAddress.copyWith(label: label);
            }
          } else {
            try {
              if (serdBdkTx.output == null) throw 'No output object';
              final scriptPubkeyString = serdBdkTx.output
                  ?.firstWhere(
                    (output) => output.value == amountSentToExternal.toInt(),
                  )
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
              final addressStr = addressStruct.asString();

              (externalAddress, _) = await walletAddress.addAddressToWallet(
                address: (null, addressStr),
                wallet: wallet,
                spentTxId: bdkTx.txid,
                kind: AddressKind.external,
                state: AddressStatus.used,
                spendable: false,
                label: label,
              );
              // Future.delayed(const Duration(milliseconds: 100));
            } catch (e) {
              // usually scriptpubkey not available
              // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
              // can also be serializedBdkTx
            }
          }
          updatedTx = updatedTx.copyWith(
            toAddress: externalAddress != null ? externalAddress.address : '',
            // fromAddress: '',
          );
          if (externalAddress != null) {
            updatedTx = addOutputAddresses(externalAddress, updatedTx);
          }
          //
          //
          // HANDLE CHANGE
          //
          //

          changeAddress = wallet.getAddressFromAddresses(
            updatedTx.txid,
            isSend: !updatedTx.isReceived(),
            kind: AddressKind.change,
          );

          final amountChange = bdkTx.received;

          if (changeAddress != null) {
            if (changeAddress.label != null &&
                changeAddress.label!.isNotEmpty) {
              label = changeAddress.label;
            } else {
              changeAddress = changeAddress.copyWith(label: label);
            }
          } else {
            try {
              if (serdBdkTx.output == null) throw 'No output object';
              final scriptPubkeyString = serdBdkTx.output
                  ?.firstWhere(
                    (output) => output.value == amountChange,
                  )
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
              final addressStr = addressStruct.asString();

              (changeAddress, _) = await walletAddress.addAddressToWallet(
                address: (null, addressStr),
                wallet: wallet,
                spentTxId: bdkTx.txid,
                kind: AddressKind.change,
                state: AddressStatus.used,
                label: label,
              );
            } catch (e) {
              // usually scriptpubkey not available
              // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
              // print(e);
            }
          }
          if (changeAddress != null) {
            updatedTx = addOutputAddresses(changeAddress, updatedTx);
          }
        } else if (updatedTx.isReceived()) {
          depositAddress = wallet.getAddressFromAddresses(
            updatedTx.txid,
            isSend: !updatedTx.isReceived(),
            kind: AddressKind.deposit,
          );
          final amountReceived = bdkTx.received;

          if (depositAddress != null) {
            if (depositAddress.label != null &&
                depositAddress.label!.isNotEmpty) {
              label = depositAddress.label;
            } else {
              depositAddress = depositAddress.copyWith(label: label);
            }
          } else {
            try {
              if (serdBdkTx.output == null) throw 'No output object';
              final scriptPubkeyString = serdBdkTx.output
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
              final addressStr = addressStruct.asString();

              (depositAddress, _) = await walletAddress.addAddressToWallet(
                address: (null, addressStr),
                wallet: wallet,
                spentTxId: bdkTx.txid,
                kind: AddressKind.deposit,
                state: AddressStatus.used,
                // spendable: true,
                label: label,
              );
            } catch (e) {
              // usually scriptpubkey not available
              // results in : BdkException.generic(e: ("script is not a p2pkh, p2sh or witness program"))
              // print(e);
            }
          }
          updatedTx = updatedTx.copyWith(
            toAddress: depositAddress != null ? depositAddress.address : '',
            // fromAddress: '',
          );
          if (depositAddress != null) {
            final txObj2 = addOutputAddresses(depositAddress, updatedTx);
            updatedTx = txObj2.copyWith(outAddrs: txObj2.outAddrs);
          }
        }

        if (foundStoredUTx) {
          final uTx = unsignedTxs.removeAt(idxUnsignedTx);
          transactions.add(
            updatedTx.copyWith(
              label: uTx.label,
              outAddrs: uTx.outAddrs,
            ),
          );
        } else {
          transactions.add(updatedTx.copyWith(label: label));
        }
      }

      final List<Transaction> pendingTxs = [];
      final List<List<bdk.TxIn>> pendingTxInputs = [];
      for (final tx in transactions) {
        if (tx.isPending() && tx.isReceived()) {
          pendingTxs.add(tx);
          // final ip = await tx.bdkTx?.transaction?.input() ?? [];
          // pendingTxInputs.add(ip);
        }
      }

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
          // print('${tx.txid} is RBF parent of a receive tx');
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
    int? absFee,
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
      final frozenUtxos = wallet.allFreezedUtxos();
      final spendableUtxos = wallet.spendableUtxos();

      var txBuilder = bdk.TxBuilder();
      final bdkAddress = await bdk.Address.fromString(
        s: address,
        network: wallet.getBdkNetwork()!,
      );

      for (final utxo in frozenUtxos) {
        final outPoint = utxo.getUtxosOutpoints();
        txBuilder = txBuilder.addUnSpendable(outPoint);
      }

      final script = bdkAddress.scriptPubkey();
      if (sendAllCoin) {
        if (frozenUtxos.isEmpty) {
          txBuilder = txBuilder.drainWallet().drainTo(script);
        } else {
          amount = spendableUtxos
              .map((u) => u.value)
              .reduce((value, element) => value + element);
          txBuilder = txBuilder.drainWallet().drainTo(script);
        }
      } else {
        txBuilder = txBuilder.addRecipient(script, BigInt.from(amount!));
      }

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

      txBuilder = feeRate == 0
          ? txBuilder.feeAbsolute(BigInt.from(absFee ?? 100))
          : txBuilder.feeRate(feeRate);

      if (enableRbf) txBuilder = txBuilder.enableRbf();

      final txResult = await txBuilder.finish(pubWallet);

      final psbt = txResult.$1;
      final txDetails = txResult.$2;

      final extractedTx = psbt.extractTx();
      final outputs = await extractedTx.output();
      final inputs = await extractedTx.input();

      final bdkNetwork = wallet.getBdkNetwork();
      if (bdkNetwork == null) throw 'No bdkNetwork';

      final outAddrsFutures = outputs.map((txOut) async {
        final scriptAddress = await bdk.Address.fromScript(
          script: bdk.ScriptBuf(bytes: txOut.scriptPubkey.bytes),
          network: bdkNetwork,
        );
        final addressStr = scriptAddress.asString();
        if (txOut.value == BigInt.from(amount!) &&
            !sendAllCoin &&
            addressStr == address) {
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
            highestPreviousBalance: txOut.value.toInt(),
            balance: txOut.value.toInt(),
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
          // print('no matching input with label');
        }
      });
      await Future.wait(inAddrsFutures);
      final List<Address> outAddrs = await Future.wait(outAddrsFutures);
      final feeAmt = txResult.$1.feeAmount();
      final psbtStr = psbt.serialize();
      // if (note != null || note != '') labels.add(note!);
      final labelsString = labels.isNotEmpty ? labels.last : '';

      final Transaction tx = Transaction(
        txid: txDetails.txid,
        rbfEnabled: enableRbf,
        received: txDetails.received.toInt(),
        sent: txDetails.sent.toInt(),
        fee: feeAmt?.toInt() ?? 0,
        feeRate: feeRate,
        height: txDetails.confirmationTime?.height,
        timestamp: 0,
        // txDetails.confirmationTime?.timestamp ?? 0,
        label: (note == null || note == '')
            ? labelsString
            : note, // for now we just take the first label
        toAddress: address,
        outAddrs: outAddrs,
        psbt: base64Encode(psbtStr),
      );
      return ((tx, feeAmt?.toInt(), base64Encode(psbtStr)), null);
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

  Future<((bdk.Transaction, String)?, Err?)> signTx({
    required String psbt,
    // required bdk.Blockchain blockchain,
    required bdk.Wallet bdkWallet,
    // required String address,
  }) async {
    try {
      print('signTx psbt: $psbt');
      final psbtStruct = await bdk.PartiallySignedTransaction.fromString(psbt);
      final tx = psbtStruct.extractTx();
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
      final psbtStr = psbtStruct.serialize();
      print('signTx psbtStr: ${base64Encode(psbtStr)}');
      return ((tx, base64Encode(psbtStr)), null);
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
      final tx = psbtStruct.extractTx();
      vsize = (await tx.vsize()).toInt();

      await blockchain.broadcast(transaction: tx);
      final txid = psbtStruct.txid();

      final swapTxType = transaction.swapTx?.getSwapTxTypeForParent();
      final newTx = transaction.copyWith(
        txid: txid,
        label: note,
        toAddress: address,
        broadcastTime: DateTime.now().millisecondsSinceEpoch,
        swapTx: transaction.swapTx?.copyWith(
          claimTxid: swapTxType == SwapTxType.claim ? txid : null,
          lockupTxid: swapTxType == SwapTxType.lockup ? txid : null,
        ),
        // oldTx: false,
      );

      final txs = wallet.transactions.toList();
      // final txs = walletBloc.state.wallet!.transactions.toList();
      final idx = txs.indexWhere((element) => element.txid == newTx.txid);
      if (idx != -1) {
        txs.removeAt(idx);
        txs.insert(idx, newTx);
      } else {
        txs.add(newTx);
      }
      // txs.add(newTx);

      // TODO: Not the right place. Also duplicated in BDKTransaction / LWKTransaction
      // Optimize it later
      final swaps = wallet.swaps.toList();
      if (newTx.swapTx != null) {
        final swapIndex =
            swaps.indexWhere((swap) => swap.id == newTx.swapTx!.id);
        if (swapIndex != -1) {
          swaps.removeAt(swapIndex);
          swaps.insert(swapIndex, newTx.swapTx!);
        } else {
          swaps.add(newTx.swapTx!);
        }
      }

      final w = wallet.copyWith(transactions: txs, swaps: swaps);

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
        final bdk.Transaction bdkTx = psbt.extractTx();
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

      final psbt = txResult.$1;
      final txDetails = txResult.$2;

      final psbtStr = psbt.serialize();

      final newTx = Transaction(
        txid: txDetails.txid,
        received: txDetails.received.toInt(),
        sent: txDetails.sent.toInt(),
        fee: txDetails.fee?.toInt() ?? 0,
        feeRate: feeRate,
        height: txDetails.confirmationTime?.height,
        timestamp: txDetails.confirmationTime?.timestamp.toInt() ?? 0,
        label: tx.label,
        toAddress: tx.toAddress,
        psbt: base64Encode(psbtStr),
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
