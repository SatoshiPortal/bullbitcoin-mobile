import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BDKAddress {
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
}
