import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
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
        label: addressList[existingAddressIndex].label ?? address.label,
      );
      addressList[existingAddressIndex] = updatedAddress;
    } else {
      addressList.add(address);
    }
  }

  Future<(Wallet?, Err?)> updateAddressesFromTxs(Wallet wallet) async {
    final updatedAddresses = List<Address>.from(wallet.myAddressBook);
    final updatedToAddresses = List<Address>.from(wallet.externalAddressBook ?? []);

    for (final tx in wallet.transactions) {
      for (final address in tx.outAddrs) {
        if (tx.isReceived()) {
          // works since we currently do not save senders change
          // in getTransactions we only store the address that match
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

  Future<(Wallet?, Err?)> updateAddressesForOneTx(Wallet wallet, Transaction tx) async {
    try {
      final updatedAddresses = List<Address>.from(wallet.myAddressBook);
      final updatedToAddresses = List<Address>.from(wallet.externalAddressBook ?? []);

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

      return (
        wallet.copyWith(
          myAddressBook: updatedAddresses,
          externalAddressBook: updatedToAddresses,
        ),
        null
      );
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<bool> walletExists(String mnemonicFingerprint, List<Wallet> wallets) async {
    for (final wallet in wallets) {
      if (wallet.mnemonicFingerprint == mnemonicFingerprint) return true;
    }
    return false;
  }
}
