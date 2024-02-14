import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletUtxo {
  Future<(Wallet?, Err?)> loadUtxos({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final unspentList = await bdkWallet.listUnspent();
      final myAddress = wallet.myAddressBook;
      final network = wallet.getBdkNetwork();
      if (network == null) return (null, Err('Network is null'));

      for (final unspent in unspentList) {
        final UTXO utxo = UTXO(
          txid: unspent.outpoint.txid,
          isSpent: unspent.isSpent,
          value: unspent.outpoint.vout,
          label: '',
        );
      }
      /*
    final unspentList = await bdkWallet.listUnspent();
    final utxoUpdatedAddresses =
        wallet.myAddressBook.map((item) => item.copyWith(utxos: null)).toList();
    final network = wallet.getBdkNetwork();
    if (network == null) return (null, Err('Network is null'));

    for (final unspent in unspentList) {
      final scr = await bdk.Script.create(unspent.txout.scriptPubkey.inner);
      final addresss = await bdk.Address.fromScript(
        scr,
        network,
      );
      final addressStr = addresss.toString();

      late bool isRelated = false;
      // late String txLabel = '';
      final address = utxoUpdatedAddresses.firstWhere(
        (a) => a.address == addressStr,
        // if the address does not exist, its because its new change
        orElse: () => Address(
          address: addressStr,
          kind: AddressKind.change,
          state: AddressStatus.active,
          highestPreviousBalance: unspent.txout.value,
        ),
      );

      final List<bdk.LocalUtxo> utxos = address.utxos?.toList() ?? [];
      for (final tx in wallet.transactions) {
        for (final addrs in tx.outAddrs) {
          if (addrs.address == addressStr) {
            isRelated = true;
            // txLabel = tx.label ?? '';
          }
        }
      }
      // tjhe above might not be the best way to update change label from a send tx

      if (utxos.indexWhere((u) => u.outpoint.txid == unspent.outpoint.txid) == -1)
        utxos.add(unspent);

      var updated = address.copyWith(
        utxos: utxos,
        localUtxos: UTXO.fromUTXOList(utxos),
        // label: isRelated ? address.label : txLabel,
        state: AddressStatus.active,
        highestPreviousBalance: unspent.txout.value,
      );

      if (updated.calculateBalance() > 0 &&
          updated.calculateBalance() > updated.highestPreviousBalance)
        updated = updated.copyWith(
          highestPreviousBalance: updated.calculateBalance(),
        );

      utxoUpdatedAddresses.removeWhere((a) => a.address == address.address);
      utxoUpdatedAddresses.add(updated);
    }
    final w = wallet.copyWith(myAddressBook: utxoUpdatedAddresses);
    */

      return (wallet, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while loading utxos',
          solution: 'Please try again.',
        )
      );
    }
  }
}
