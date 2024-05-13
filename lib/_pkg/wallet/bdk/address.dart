import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BDKAddress {
  Future<(String?, Err?)> peekIndex(bdk.Wallet bdkWallet, int idx) async {
    try {
      final address = await bdkWallet.getAddress(
        addressIndex: bdk.AddressIndex.peek(index: idx),
      );

      final addr = await address.address.asString();

      return (addr, null);
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
        final addressStr = await address.address.asString();
        final contain = wallet.myAddressBook.where(
          (element) => element.address == addressStr,
        );
        if (contain.isEmpty)
          addresses.add(
            Address(
              address: addressStr,
              index: address.index,
              kind: AddressKind.deposit,
              state: AddressStatus.unused,
              isLiquid: wallet.baseWalletType == BaseWalletType.Liquid,
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
            address: await addressLastUnused.address.asString(),
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
        final addressStr = await address.address.asString();
        final contain = wallet.myAddressBook.where(
          (element) => element.address == addressStr,
        );
        if (contain.isEmpty)
          addresses.add(
            Address(
              address: addressStr,
              index: address.index,
              kind: AddressKind.change,
              state: AddressStatus.unused,
              isLiquid: wallet.baseWalletType == BaseWalletType.Liquid,
            ),
          );
        else {
          // migration for existing users so their change index is updated
          // index used to be null
          final index = wallet.myAddressBook.indexWhere(
            (element) => element.address == addressStr,
          );
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

  Future<(Wallet?, Err?)> updateUtxoAddresses(Wallet wallet) async {
    try {
      final List<UTXO> utxos = wallet.utxos.toList();
      final List<Address> myAddresses = wallet.myAddressBook.toList();
      final List<Address> updatedAddresses = [];

      for (final addr in myAddresses) {
        AddressStatus addressStatus = addr.state;
        int balance = 0;
        final matches = utxos
            .where((utxo) => utxo.address.address == addr.address)
            .toList();
        if (matches.isEmpty) {
          if (addr.state == AddressStatus.active) {
            addressStatus = AddressStatus.used;
          }
        } else {
          addressStatus = AddressStatus.active;
          balance = matches.fold(0, (sum, utxo) => sum + utxo.value);
        }
        updatedAddresses
            .add(addr.copyWith(state: addressStatus, balance: balance));
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
}
