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
        List.from(wallet.addresses.where((address) => address.state == AddressStatus.unused))
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
    final addresses = wallet.addresses;

    String? label;
    if (addresses.any((element) => element.address == address)) {
      final x = addresses.firstWhere(
        (element) => element.address == address,
      );
      label = x.label;
    }

    return label;
  }

  // get lastUnused from bdk
  // can be optimized
  Future<(Wallet?, Err?)> loadAddresses({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final addressLastUnused = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.lastUnused(),
      );
      Wallet w;

      final List<Address> addresses = [...wallet.addresses];

      for (var i = 0; i <= addressLastUnused.index; i++) {
        final address = await bdkWallet.getAddress(
          addressIndex: bdk.AddressIndex.peek(index: i),
        );
        final contain = wallet.addresses.where(
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

      addresses.sort((a, b) {
        final int indexA = a.index ?? 0;
        final int indexB = b.index ?? 0;
        return indexB.compareTo(indexA);
      });

      if (wallet.lastGeneratedAddress == null ||
          addressLastUnused.index >= wallet.lastGeneratedAddress!.index!)
        w = wallet.copyWith(
          addresses: addresses,
          lastGeneratedAddress: Address(
            address: addressLastUnused.address,
            index: addressLastUnused.index,
            kind: AddressKind.deposit,
            state: AddressStatus.unused,
          ),
        );
      else
        w = wallet.copyWith(
          addresses: addresses,
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
        state: AddressStatus.unused,
      );

      final Wallet w = updatedWallet.copyWith(
        lastGeneratedAddress: address,
      );

      return (w, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(Wallet?, Err?)> firstAddress({
    required Wallet wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    try {
      final addressNewIndex = await bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.peek(index: 0),
      );
      Wallet w;

      final List<Address> addresses = [...wallet.addresses];

      final contain = wallet.addresses.where(
        (element) => element.address == addressNewIndex.address,
      );
      if (contain.isEmpty)
        addresses.add(
          Address(
            address: addressNewIndex.address,
            index: addressNewIndex.index,
            kind: AddressKind.deposit,
            state: AddressStatus.unset,
          ),
        );

      w = wallet.copyWith(
        addresses: addresses,
        lastGeneratedAddress: Address(
          address: addressNewIndex.address,
          index: addressNewIndex.index,
          kind: AddressKind.deposit,
          state: AddressStatus.unused,
        ),
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
      final addresses = wallet.addresses.toList();
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
          // if the address does not exist, its because its new change
          orElse: () => Address(
            address: addressStr,
            kind: AddressKind.change,
            state: AddressStatus.active,
          ),
        );

        final utxos = address.utxos?.toList() ?? [];
        for (final tx in wallet.transactions) {
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

        var updated = address.copyWith(
          utxos: utxos,
          label: isRelated ? address.label : txLabel,
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
      final w = wallet.copyWith(addresses: addresses);

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
    AddressKind? kind,
    AddressStatus state = AddressStatus.unset,
    bool spendable = true,
  }) async {
    try {
      final (idx, adr) = address;
      final addresses = (kind == AddressKind.external
              ? wallet.toAddresses?.toList()
              : wallet.addresses.toList()) ??
          <Address>[];

      Address a;

      final existing = addresses.indexWhere(
        (element) => element.address == adr,
      );
      final addressExists = existing != -1;
      if (addressExists) {
        a = addresses.removeAt(existing);
        a = a.copyWith(
          label: label,
          spentTxId: spentTxId,
          state: state,
          spendable: spendable,
        );
        addresses.insert(existing, a);
      } else {
        a = Address(
          address: adr,
          index: idx,
          label: label,
          spentTxId: spentTxId,
          kind: kind!,
          state: state,
          spendable: spendable,
        );
        addresses.add(a);
      }

      final w = kind == AddressKind.external
          ? wallet.copyWith(toAddresses: addresses)
          : wallet.copyWith(addresses: addresses);

      return (a, w);
    } catch (e) {
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
