// ignore_for_file: unused_local_variable

import 'package:bb_mobile/_model/address.dart';
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

  Future<(({int index, String address})?, Err?)> lastUnused({
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final address = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.lastUnused(),
      );

      return ((index: address.index, address: address.address), null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  (Address?, Err?) rotateAddress(Wallet wallet, int currentIndex) {
    // Filter out addresses with AddressStatus.unused and then sort them by index
    final List<Address> sortedAddresses =
        List.from(wallet.myAddressBook.where((address) => address.state == AddressStatus.unused))
          ..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));

    // Find the index of the address with the current index
    final int foundIndex = sortedAddresses.indexWhere((address) => address.index == currentIndex);

    // If not found, throw an error or handle it accordingly
    if (foundIndex == -1) {
      // ignore: unnecessary_statements
      return (
        null,
        Err(
          'Wallet not synced. Sync wallet on home page to load more addresses.',
        ),
      );
    }

    // Get the next unused address. If it's the last unused address, wrap around to 0 index
    if (foundIndex + 1 < sortedAddresses.length) {
      return (sortedAddresses[foundIndex + 1], null);
    } else {
      return (sortedAddresses[0], null);
    }
  }

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
    } catch (e) {
      return (null, Err(e.toString()));
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
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

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

  Future<(Wallet?, Err?)> updateUtxos({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final unspentList = await bdkWallet.listUnspent();
      final addresses = wallet.myAddressBook.toList();
      for (final unspent in unspentList) {
        final scr = await bdk.Script.create(unspent.txout.scriptPubkey.internal);
        final addresss = await bdk.Address.fromScript(
          scr,
          wallet.getBdkNetwork(),
        );
        final addressStr = addresss.toString();

        late bool isRelated = false;
        // late String txLabel = '';
        final address = addresses.firstWhere(
          (a) => a.address == addressStr,
          // if the address does not exist, its because its new change
          orElse: () => Address(
            address: addressStr,
            kind: AddressKind.change,
            state: AddressStatus.active,
          ),
        );

        final utxos = address.utxos?.toList() ?? [];
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
          // label: isRelated ? address.label : txLabel,
          state: AddressStatus.active,
        );

        if (updated.calculateBalance() > 0 &&
            updated.calculateBalance() > updated.highestPreviousBalance)
          updated = updated.copyWith(
            highestPreviousBalance: updated.calculateBalance(),
          );

        addresses.removeWhere((a) => a.address == address.address);
        addresses.add(updated);
      }
      final w = wallet.copyWith(myAddressBook: addresses);

      return (w, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

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
          highestPreviousBalance: existing.highestPreviousBalance,
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
