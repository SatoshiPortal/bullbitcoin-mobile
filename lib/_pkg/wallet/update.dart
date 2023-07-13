import 'dart:convert';

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/_pkg/wallet/read.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletUpdate {
  Future<Err?> updateWallet({
    required Wallet wallet,
    required IStorage storage,
    required WalletRead walletRead,
  }) async {
    try {
      final (w, err) = await walletRead.getWalletDetails(
        saveDir: wallet.getStorageString(),
        storage: storage,
      );
      if (err != null) throw err;

      final _ = await storage.saveValue(
        key: wallet.getStorageString(),
        value: jsonEncode(
          wallet
              .copyWith(
                mnemonic: w!.mnemonic,
                password: w.password,
                internalDescriptor: w.internalDescriptor,
              )
              .toJson(),
        ),
      );
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<(Address, Wallet)> updateWalletAddress({
    required (int, String) address,
    required Wallet wallet,
    String? label,
    bool isSend = false,
    String? sentTxId,
    bool? freeze,
  }) async {
    try {
      final (idx, adr) = address;
      final addresses =
          (isSend ? wallet.toAddresses?.toList() : wallet.addresses?.toList()) ?? <Address>[];

      // if (label == null && ad.any((element) => element.address == address.address)) {
      //   return ad.firstWhere((element) => element.address == address.address);
      // }

      Address a;

      final existing = addresses.indexWhere(
        (element) => element.address == adr,
      );
      if (existing != -1) {
        a = addresses.removeAt(existing);
        if (freeze != null) a = a.copyWith(unspendable: freeze);
        a = a.copyWith(
          label: label,
          sentTxId: sentTxId,
          isReceive: !isSend,
        );
        addresses.insert(existing, a);
      } else {
        a = Address(
          address: adr,
          index: idx,
          label: label,
          sentTxId: sentTxId,
          isReceive: !isSend,
        );
        if (freeze != null) a = a.copyWith(unspendable: freeze);
        addresses.add(a);
      }

      final w =
          isSend ? wallet.copyWith(toAddresses: addresses) : wallet.copyWith(addresses: addresses);

      // await updateWallet(w);
      // walletCubit.updateWallet(w);

      return (a, w);
    } catch (e) {
      rethrow;
    }
  }

  Future<Err?> addWalletToList({
    required Wallet wallet,
    required IStorage storage,
    required IStorage secureStorage,
  }) async {
    try {
      final (walletsJsn, err) = await storage.getValue(StorageKeys.wallets);
      final saveDir = wallet.getStorageString();
      if (err != null) {
        final jsn = jsonEncode({
          'wallets': [saveDir]
        });
        final _ = await storage.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
        final __ = await secureStorage.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
      } else {
        final walletsObjs = jsonDecode(walletsJsn!)['wallets'] as List<dynamic>;

        final List<String> fingerprints = [];
        for (final w in walletsObjs) {
          fingerprints.add(w as String);
        }

        fingerprints.add(saveDir);

        final jsn = jsonEncode({
          'wallets': [...fingerprints]
        });
        final _ = await storage.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
        final __ = await secureStorage.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
      }

      await secureStorage.saveValue(
        key: saveDir,
        value: jsonEncode(wallet.toJson()),
      );

      await storage.saveValue(
        key: saveDir,
        value: jsonEncode(
          wallet
              .copyWith(
                mnemonic: '',
                password: '',
                internalDescriptor: '',
                externalDescriptor: '',
                xpub: '',
              )
              .toJson(),
        ),
      );

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<((int, String, String?)?, Err?)> getNewAddress({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final addresses = wallet.addresses ?? <Address>[];

      final address = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.new(),
      );

      String? label;
      if (addresses.any((element) => element.address == address.address)) {
        final x = addresses.firstWhere(
          (element) => element.address == address.address,
        );
        label = x.label;
      }

      return ((address.index, address.address, label), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
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
      return (null, Err(e.toString()));
    }
  }

  Future<((Transaction?, int?, String)?, Err?)> buildTx({
    required bool watchOnly,
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
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

      final txResult = await txBuilder.finish(bdkWallet);

      if (watchOnly) {
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

        return ((tx, null, txResult.psbt.psbtBase64), null);
      }

      final signedPSBT = await bdkWallet.sign(psbt: txResult.psbt);
      final feeAmt = await signedPSBT.feeAmount();

      return ((null, feeAmt, signedPSBT.psbtBase64), null);
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

      final txs = wallet.transactions?.toList() ?? [];
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

  Future<(String?, Err?)> getAddressAtIdx(bdk.Wallet bdkWallet, int idx) async {
    try {
      final address = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.peek(index: 0),
      );

      return (address.address, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Transaction?, Err?)> buildBumpFeeTx({
    required Transaction tx,
    required double feeRate,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final txBuilder = bdk.BumpFeeTxBuilder(
        txid: tx.txid,
        feeRate: feeRate,
      );

      final txResult = await txBuilder.finish(bdkWallet);
      final signedPSBT = await bdkWallet.sign(psbt: txResult.psbt);

      final txDetails = txResult.txDetails;

      final newTx = Transaction(
        txid: txDetails.txid,
        received: txDetails.received,
        sent: txDetails.sent,
        fee: txDetails.fee ?? 0,
        height: txDetails.confirmationTime?.height,
        timestamp: txDetails.confirmationTime?.timestamp,
        label: tx.label,
        toAddress: tx.toAddress,
        outAddresses: tx.outAddresses,
        psbt: signedPSBT.psbtBase64,
      );
      return (newTx, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
