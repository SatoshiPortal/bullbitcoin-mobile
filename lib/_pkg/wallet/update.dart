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
      final updatedAddress = addressList[existingAddressIndex].copyWith(state: address.state);
      addressList[existingAddressIndex] = updatedAddress;
    } else {
      addressList.add(address);
    }
  }

  (Wallet?, Err?) updateAddressesFromTxs(Wallet wallet) {
    final updatedAddresses = List<Address>.from(wallet.addresses);
    final updatedToAddresses = List<Address>.from(wallet.toAddresses ?? []);

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
        addresses: updatedAddresses,
        toAddresses: updatedToAddresses,
      ),
      null
    );
  }
}
