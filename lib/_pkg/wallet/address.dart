import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletAddress {
  Future<(({int index, String address})?, Err?)> getNewAddress({
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final address = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.new(),
      );

      return ((index: address.index, address: address.address), null);
    } catch (e) {
      return (null, Err(e.toString()));
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
      return (null, Err(e.toString()));
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
      return (null, Err(e.toString()));
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
      return (null, Err(e.toString()));
    }
  }

  Future<(Address, Wallet)> addAddressToWallet({
    required (int, String) address,
    required Wallet wallet,
    String? label,
    bool isSend = false,
    String? sentTxId,
    bool? freeze,
    bool isMine = true,
  }) async {
    try {
      final (idx, adr) = address;
      final addresses =
          (isSend ? wallet.toAddresses?.toList() : wallet.addresses?.toList()) ?? <Address>[];

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
          isMine: isMine,
        );
        addresses.insert(existing, a);
      } else {
        a = Address(
          address: adr,
          index: idx,
          label: label,
          sentTxId: sentTxId,
          isReceive: !isSend,
          isMine: isMine, // !isSend does not always mean isMine - change isMine and isSend
        );
        if (freeze != null) a = a.copyWith(unspendable: freeze);
        addresses.add(a);
      }

      final w =
          isSend ? wallet.copyWith(toAddresses: addresses) : wallet.copyWith(addresses: addresses);

      return (a, w);
    } catch (e) {
      rethrow;
    }
  }

  Future<(Wallet?, Err?)> updateRelatedAddressLabels({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
    // ignore: type_annotate_public_apis
    required String label,
    required String txid,
  }) async {
    try {
      return (wallet, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Wallet?, Err?)> updateChangeLabel({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
    // ignore: type_annotate_public_apis
    required String txid,
    required String label,
  }) async {
    try {
      final utxos = await bdkWallet.listUnspent();
      final addresses = wallet.addresses?.toList() ?? [];

      final newChange = utxos.firstWhere(
        (element) => element.keychain == bdk.KeychainKind.Internal && element.outpoint.txid == txid,
      );
      final scr = await bdk.Script.create(newChange.txout.scriptPubkey.internal);
      final addresss = await bdk.Address.fromScript(
        scr,
        wallet.getBdkNetwork(),
      );
      final a = Address(address: addresss.toString(), index: -1, label: label);
      // final addressStr = addresss.toString();
      addresses.add(a);
      final w = wallet.copyWith(addresses: addresses);
      return (w, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
