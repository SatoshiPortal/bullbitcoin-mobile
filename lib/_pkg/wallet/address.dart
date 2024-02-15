// ignore_for_file: unused_local_variable

import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletAddress {
  Future<String?> getLabel({required Wallet wallet, required String address}) async {
    final addresses = wallet.myAddressBook;

    String? label;
    if (addresses.any((element) => element.address == address)) {
      final x = addresses.firstWhere(
        (element) => element.address == address,
      );
      label = x.label;
    }

    return label;
  }

  Future<(Wallet?, Err?)> loadAddresses({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final addressLastUnused = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.lastUnused(),
      );

      final List<Address> addresses = [...wallet.myAddressBook];

      for (var i = 0; i <= addressLastUnused.index; i++) {
        final address = await bdkWallet.getAddress(
          addressIndex: bdk.AddressIndex.peek(index: i),
        );
        final contain = wallet.myAddressBook.where(
          (element) => element.address == address.address,
        );
        if (contain.isEmpty)
          addresses.add(
            Address(
              address: address.address,
              index: address.index,
              kind: AddressKind.deposit,
              state: AddressStatus.unused,
            ),
          );
      }
      // Future.delayed(const Duration(milliseconds: 1600));
      addresses.sort((a, b) {
        final int indexA = a.index ?? 0;
        final int indexB = b.index ?? 0;
        return indexB.compareTo(indexA);
      });

      Wallet w;

      if (wallet.lastGeneratedAddress == null ||
          addressLastUnused.index >= wallet.lastGeneratedAddress!.index!)
        w = wallet.copyWith(
          myAddressBook: addresses,
          lastGeneratedAddress: Address(
            address: addressLastUnused.address,
            index: addressLastUnused.index,
            kind: AddressKind.deposit,
            state: AddressStatus.unused,
          ),
        );
      else
        w = wallet.copyWith(
          myAddressBook: addresses,
        );
      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while loading addresses',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(Wallet?, Err?)> loadChangeAddresses({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final addressLastUnused = await bdkWallet.getInternalAddress(
        addressIndex: const bdk.AddressIndex.lastUnused(),
      );

      final List<Address> addresses = [...wallet.myAddressBook];

      for (var i = 0; i <= addressLastUnused.index; i++) {
        final address = await bdkWallet.getInternalAddress(
          addressIndex: bdk.AddressIndex.peek(index: i),
        );
        final contain = wallet.myAddressBook.where(
          (element) => element.address == address.address,
        );
        if (contain.isEmpty)
          addresses.add(
            Address(
              address: address.address,
              index: address.index,
              kind: AddressKind.change,
              state: AddressStatus.unused,
            ),
          );
        else {
          // migration for existing users so their change index is updated
          // index used to be null
          final index =
              wallet.myAddressBook.indexWhere((element) => element.address == address.address);
          final change = addresses.removeAt(index);
          addresses.add(change.copyWith(index: i));
        }
      }
      // Future.delayed(const Duration(milliseconds: 1600));
      addresses.sort((a, b) {
        final int indexA = a.index ?? 0;
        final int indexB = b.index ?? 0;
        return indexB.compareTo(indexA);
      });

      Wallet w;

      w = wallet.copyWith(
        myAddressBook: addresses,
      );
      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while loading addresses',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(Wallet?, Err?)> newAddress({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final addressNew = await bdkWallet.getAddress(
        addressIndex: bdk.AddressIndex.peek(index: wallet.lastGeneratedAddress!.index! + 1),
      );

      final (address, updatedWallet) = await addAddressToWallet(
        address: (
          addressNew.index,
          addressNew.address,
        ),
        wallet: wallet,
        kind: AddressKind.deposit,
      );

      // final myUpdatedAddressBook = List<Address>.from(wallet.myAddressBook);
      // myUpdatedAddressBook.add(address);

      final w = updatedWallet.copyWith(
        lastGeneratedAddress: address,
        // myAddressBook: myUpdatedAddressBook,
      );

      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while generating new address',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(String?, Err?)> peekIndex(bdk.Wallet bdkWallet, int idx) async {
    try {
      final address = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.peek(index: 0),
      );

      return (address.address, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while getting address',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<(Wallet?, Err?)> updateUtxoAddresses({
    required Wallet wallet,
  }) async {
    try {
      final List<UTXO> utxos = wallet.utxos.toList();
      final List<Address> myAddresses = wallet.myAddressBook.toList();
      final List<Address> updatedAddresses = [];

      for (final addr in myAddresses) {
        Address updatedAddress = addr;
        final matches = utxos.where((utxo) => utxo.address.address == addr.address).toList();
        if (matches.isEmpty) {
          if (addr.state == AddressStatus.active) {
            updatedAddress = addr.copyWith(state: AddressStatus.used, balance: 0);
          } else {
            updatedAddress = addr.copyWith(balance: 0);
          }
        } else {
          for (final match in matches) {
            updatedAddress = addr.copyWith(
              state: AddressStatus.active,
              balance: match.value + updatedAddress.balance,
            );
          }
        }
        updatedAddresses.add(updatedAddress);
      }
      final w = wallet.copyWith(
        myAddressBook: updatedAddresses,
      );
      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while updated utxo address',
          solution: 'Please try again.',
        )
      );
    }
  }

/*
  Future<(Wallet?, Err?)> updateUtxos({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final unspentList = await bdkWallet.listUnspent();
      final utxoUpdatedAddresses =
          wallet.myAddressBook.map((item) => item.copyWith(utxos: null)).toList();
      final network = wallet.getBdkNetwork();
      if (network == null) return (null, Err('Network is null'));

      // For each unspent from bdk
      for (final unspent in unspentList) {
        // Find the received Address in txout
        final scr = await bdk.Script.create(unspent.txout.scriptPubkey.inner);
        final addresss = await bdk.Address.fromScript(
          scr,
          network,
        );
        final addressStr = addresss.toString();

        late bool isRelated = false;
        // late String txLabel = '';
        // find any address in myAddressBook that matches the received address. If not, create a new change address
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

        // match this address with txn list in wallet.
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

      return (w, null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while updating utxos',
          solution: 'Please try again.',
        )
      );
    }
  }
  */

  Future<(Address, Wallet)> addAddressToWallet({
    required (int?, String) address,
    required Wallet wallet,
    String? label,
    String? spentTxId,
    required AddressKind kind,
    AddressStatus state = AddressStatus.unused,
    bool spendable = true,
    // int highestPreviousBalance = 0,
  }) async {
    try {
      final (idx, adr) = address;
      final addresses = (kind == AddressKind.external
              ? wallet.externalAddressBook?.toList()
              : wallet.myAddressBook.toList()) ??
          <Address>[];

      Address updated;
      final existingIdx = addresses.indexWhere(
        (element) => element.address == adr,
      );
      final addressExists = existingIdx != -1;
      if (addressExists) {
        final existing = addresses.removeAt(existingIdx);
        updated = Address(
          address: existing.address,
          index: existing.index,
          label: label ?? existing.label,
          spentTxId: spentTxId ?? existing.spentTxId,
          kind: kind,
          state: state,
          spendable: spendable,
          highestPreviousBalance: existing.balance,
          // utxos: existing.utxos, // TODO: UTXO
          // localUtxos: UTXO.fromUTXOList(existing.utxos ?? []), // TODO: UTXO
        );
        addresses.insert(existingIdx, updated);
      } else {
        updated = Address(
          address: adr,
          index: idx,
          label: label,
          spentTxId: spentTxId,
          kind: kind,
          state: state,
          spendable: spendable,
          // highestPreviousBalance: highestPreviousBalance,
        );
        addresses.add(updated);
      }

      final w = kind == AddressKind.external
          ? wallet.copyWith(externalAddressBook: addresses)
          : wallet.copyWith(myAddressBook: addresses);

      return (updated, w);
    } catch (e) {
      // print('addingAddressERROR');
      // print(e);
      rethrow;
    }

    // Future<Err?> freezeUtxo({
    //   required String address,
    //   required bdk.Wallet bdkWallet,
    // }) async {
    //   try {
    //     //
    //     return null;
    //   } catch (e) {
    //     rethrow;
    //   }
    // }
  }
}
