import 'package:bb_mobile/_pkg/error.dart';
import 'package:lwk_dart/lwk_dart.dart' as lwk;

class LWKAddress {
  Future<(String?, Err?)> peekIndex(lwk.Wallet lwkWallet, int idx) async {
    try {
      final address = await lwkWallet.addressAtIndex(idx);
      return (address.standard, null);
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
