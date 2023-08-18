import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';

class WalletUpdate {
  // sync bdk wallet, import state from wallet into new native type
  // if native type exists, only update
  // for every new tx:
  // check collect vins and vouts
  // check for related addresses and inherit labels

  Future<(Wallet?, Err?)> syncUpdateWallet({
    required Wallet wallet,
  }) async {
    try {
      // sync bdk wallet, import state from wallet into new native type
      // if native type exists, only update
      // for every new tx:
      // check collect vins and vouts
      // check for related addresses and inherit labels
      return (wallet, null);
    } catch (e) {
      return (null, Err(e.toString(), expected: e.toString() == 'No bdk transactions found'));
    }
  }
}
