import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletAddress {
  Future<(({int index, String address})?, Err?)> newDeposit({
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

  Future<String?> getLabel({required Wallet wallet, required String address}) async {
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

  // Future<((int, String)?, Err?)> newAddress({
  //   required bdk.Wallet bdkWallet,
  // }) async {
  //   try {
  //     final address = await bdkWallet.getAddress(
  //       addressIndex: const bdk.AddressIndex(),
  //     );

  //     return ((address.index, address.address), null);
  //   } catch (e) {
  //     return (null, Err(e.toString()));
  //   }
  // }

  Future<(String?, Err?)> peekIndex(bdk.Wallet bdkWallet, int idx) async {
    try {
      final address = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.peek(index: 0),
      );

      return (address.address, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Wallet?, Err?)> updateAddresses({
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
        late bool isRelated = false;
        late String txLabel = '';
        final address = addresses.firstWhere(
          (a) => a.address == addressStr,
          orElse: () => Address(
            address: addressStr,
            index: -1,
          ),
        );
        final utxos = address.utxos?.toList() ?? [];
        for (final tx in wallet.transactions ?? <Transaction>[]) {
          for (final addrs in tx.outAddresses ?? []) {
            if (addrs == addressStr) {
              isRelated = true;
              txLabel = tx.label ?? '';
            }
          }
        }
        // tjhe above might not be the best way to update change label from a send tx

        if (utxos.indexWhere((u) => u.outpoint.txid == unspent.outpoint.txid) == -1)
          utxos.add(unspent);

        var updated = address.copyWith(utxos: utxos, label: isRelated ? address.label : txLabel);

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
}
