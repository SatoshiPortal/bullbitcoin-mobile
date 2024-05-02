import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:lwk_dart/lwk_dart.dart' as lwk;

class LWKAddress {
  Future<(String?, Err?)> peekIndex(lwk.Wallet lwkWallet, int idx) async {
    try {
      final address = await lwkWallet.address(index: idx);
      return (address.confidential, null);
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

  Future<(Wallet?, Err?)> loadLiquidAddresses({
    required Wallet wallet,
    required lwk.Wallet lwkWallet,
  }) async {
    try {
      final addressLastUnused = await lwkWallet.addressLastUnused();

      final List<Address> addresses = [...wallet.myAddressBook];

      // for (var i = 0; i <= addressLastUnused.index; i++) {
      for (var i = 0; i <= 3; i++) {
        final address = await lwkWallet.address(index: i);
        final contain = wallet.myAddressBook.where(
          (element) => element.address == address.confidential,
        );
        if (contain.isEmpty)
          addresses.add(
            Address(
              address: address.confidential,
              standard: address.standard,
              index: address.index,
              kind: AddressKind.deposit,
              state: AddressStatus.unused,
              isLiquid: true,
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

      if (wallet.lastGeneratedAddress == null || addressLastUnused.index >= wallet.lastGeneratedAddress!.index!)
        w = wallet.copyWith(
          myAddressBook: addresses,
          lastGeneratedAddress: Address(
            address: addressLastUnused.confidential,
            standard: addressLastUnused.standard,
            index: addressLastUnused.index,
            kind: AddressKind.deposit,
            state: AddressStatus.unused,
            isLiquid: true,
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
}
