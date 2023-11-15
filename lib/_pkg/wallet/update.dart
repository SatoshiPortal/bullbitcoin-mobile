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

  Future<(Wallet?, Err?)> updateAddressLabels(Wallet wallet, List<Address> addresses) async {
    List<Address> myAddressBook = [];
    List<Address> externalAddressBook = [];
    myAddressBook = [...wallet.myAddressBook];
    externalAddressBook = [...wallet.externalAddressBook ?? []];
    for (final address in addresses) {
      final existingMyAddressIndex = myAddressBook.indexWhere((a) => a.address == address.address);
      if (existingMyAddressIndex != -1) {
        final updatedAddress = myAddressBook[existingMyAddressIndex].copyWith(
          label: address.label,
        );
        myAddressBook[existingMyAddressIndex] = updatedAddress;
      }

      final existingExternalAddressIndex =
          externalAddressBook.indexWhere((a) => a.address == address.address);

      if (existingExternalAddressIndex != -1) {
        final updatedAddress = externalAddressBook[existingExternalAddressIndex].copyWith(
          label: address.label,
        );
        externalAddressBook[existingExternalAddressIndex] = updatedAddress;
      }
    }
    final w = wallet.copyWith(
      myAddressBook: myAddressBook,
      externalAddressBook: externalAddressBook,
    );
    return (w, null);
  }

  Future<(Wallet?, Err?)> updateTransactionLabels(Wallet wallet, List<Transaction> txs) async {
    List<Transaction> transactions = [];
    transactions = [...wallet.transactions];
    for (final tx in txs) {
      final txIndex = transactions.indexWhere((a) => a.txid == tx.txid);
      if (txIndex != -1) {
        final updatedTx = transactions[txIndex].copyWith(
          label: tx.label,
          outAddrs: tx.outAddrs.map((addr) => addr.copyWith(label: tx.label)).toList(),
        );
        transactions[txIndex] = updatedTx;
      }
    }
    final w = wallet.copyWith(transactions: transactions);
    return (w, null);
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
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: '',
          solution: 'Please try again.',
        )
      );
    }
  }

  Future<bool> walletExists(String mnemonicFingerprint, List<Wallet> wallets) async {
    if (wallets.isEmpty) return false;
    for (final wallet in wallets) {
      if (wallet.mnemonicFingerprint == mnemonicFingerprint) return true;
    }
    return false;
  }
}
