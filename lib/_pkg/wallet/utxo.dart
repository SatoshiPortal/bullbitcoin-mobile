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
      final List<Address> myAddresses = wallet.myAddressBook.toList();
      final List<Address> newAddresses = [];
      // update these addresses state based on :
      // if state is used | unused && hasUtxos -> update to active
      // if state is active && !hasUtxos -> update to used
      // also update highestPreviousBalance with utxo.value for matching address
      final network = wallet.getBdkNetwork();
      if (network == null) return (null, Err('Network is null'));

      final List<UTXO> list = [];

      for (final unspent in unspentList) {
        UTXO utxo;
        final scr = await bdk.Script.create(unspent.txout.scriptPubkey.inner);
        final addresss = await bdk.Address.fromScript(
          scr,
          network,
        );
        final addressStr = addresss.toString();
        AddressKind addressKind = AddressKind.deposit;
        String addressLabel = '';
        for (final addr in myAddresses) {
          Address updatedAddress;
          if (addr.address == addressStr) {
            updatedAddress = addr.copyWith(
              state: AddressStatus.active,
              balance: unspent.txout.value + addr.balance,
            );
            addressLabel = addr.label ?? '';
            if (addr.kind == AddressKind.change) {
              addressKind = AddressKind.change;
            } else {
              addressKind = AddressKind.deposit;
            }
          } else {
            if (addr.state == AddressStatus.active) {
              updatedAddress = addr.copyWith(state: AddressStatus.used, balance: 0);
            } else {
              updatedAddress = addr.copyWith(balance: 0);
            }
          }
          newAddresses.add(updatedAddress);
        }
        utxo = UTXO(
          txid: unspent.outpoint.txid,
          txIndex: unspent.outpoint.vout,
          isSpent: unspent.isSpent,
          value: unspent.txout.value,
          label: addressLabel,
          spendable: true,
          address: Address(
            address: addressStr,
            kind: addressKind,
            state: AddressStatus.active,
          ),
        );
        list.add(utxo);
      }

      // for (final addr in myAddresses) {
      //   final List<UTXO> associatedUtxos = [];
      //   int utxoIndex = 0;
      //   for (final unspent in unspentList) {
      //     final scr = await bdk.Script.create(unspent.txout.scriptPubkey.inner);
      //     final addresss = await bdk.Address.fromScript(
      //       scr,
      //       network,
      //     );
      //     final addressStr = addresss.toString();

      //     if (addr.address == addressStr) {
      //       associatedUtxos.add(list[utxoIndex]);
      //       list[utxoIndex] = list[utxoIndex].copyWith(address: addr, spendable: addr.spendable);
      //     }

      //     utxoIndex++;
      //   }

      //   Address updated;
      //   final int balance =
      //       associatedUtxos.fold(0, (previousValue, element) => previousValue + element.value);
      //   updated = addr.copyWith(balance: balance);
      //   if ((addr.state == AddressStatus.used || addr.state == AddressStatus.unused) &&
      //       associatedUtxos.isNotEmpty) {
      //     updated = updated.copyWith(state: AddressStatus.active);
      //     // TODO: Potential Issue: what happens when an existing wallet is synced freshly, where status is unused, since sync is yet to complete
      //   } else if (addr.state == AddressStatus.active && associatedUtxos.isEmpty) {
      //     updated = updated.copyWith(state: AddressStatus.used);
      //   }

      //   newAddresses.add(updated);
      // }

      final w = wallet.copyWith(utxos: list, myAddressBook: newAddresses);
      return (w, null);
      /*
    final utxoUpdatedAddresses =
        wallet.myAddressBook.map((item) => item.copyWith(utxos: null)).toList();

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

  // Future<(Wallet?, Err? ) updateAddressStates(    required Wallet wallet,
  //   required bdk.Wallet bdkWallet,){

  // }
}
