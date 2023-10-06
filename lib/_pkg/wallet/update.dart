import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';

class WalletUpdate {
  // sync bdk wallet, import state from wallet into new native type
  // if native type exists, only update
  // for every new tx:
  // check collect vins and vouts
  // check for related addresses and inherit labels
  void updateAddressList(List<Address> addressList, Address address) {
    final existingAddressIndex =
        addressList.indexWhere((a) => a.address == address.address && a.kind == address.kind);
    if (existingAddressIndex != -1) {
      final updatedAddress = addressList[existingAddressIndex].copyWith(
        state: address.state,
        label: address.label,
      );
      addressList[existingAddressIndex] = updatedAddress;
    } else {
      addressList.add(address);
    }
  }
  // void updateAddressListOpt(List<Address> addressList, Address address) {
  //   // Create a map for quick lookups
  //   final addressMap = {
  //     for (final addr in addressList) '${addr.address}-${addr.kind}': addr,
  //   };

  //   // Key to look for in the map
  //   final key = '${address.address}-${address.kind}';

  //   if (addressMap.containsKey(key)) {
  //     // If the address exists, update its state
  //     final updatedAddress = addressMap[key]!.copyWith(state: address.state);
  //     // Find the index of the existing address in the list
  //     final index =
  //         addressList.indexWhere((a) => a.address == address.address && a.kind == address.kind);
  //     // Update the address in the list
  //     if (index != -1) {
  //       addressList[index] = updatedAddress;
  //     }
  //   } else {
  //     // If the address doesn't exist, add it to the list
  //     addressList.add(address);
  //   }
  // }

  Future<(Wallet?, Err?)> updateAddressesFromTxs(Wallet wallet) async {
    final updatedAddresses = List<Address>.from(wallet.myAddressBook);
    final updatedToAddresses = List<Address>.from(wallet.externalAddressBook ?? []);

    for (final tx in wallet.transactions) {
      for (final address in tx.outAddrs) {
        if (tx.isReceived()) {
          updateAddressList(updatedAddresses, address);
        } else {
          if (address.kind == AddressKind.external) {
            updateAddressList(updatedToAddresses, address);
          } else if (address.kind == AddressKind.change) {
            updateAddressList(updatedAddresses, address);
          }
        }
      }
    }

    return (
      wallet.copyWith(
        myAddressBook: updatedAddresses,
        externalAddressBook: updatedToAddresses,
      ),
      null
    );
  }
}
