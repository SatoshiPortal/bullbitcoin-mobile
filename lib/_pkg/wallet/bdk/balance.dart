import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class BDKBalance {
  Future<((Wallet, Balance)?, Err?)> getBalance({
    required bdk.Wallet bdkWallet,
    required Wallet wallet,
  }) async {
    try {
      final bdkbalance = bdkWallet.getBalance();

      final balance = Balance(
        confirmed: bdkbalance.confirmed.toInt(),
        untrustedPending: bdkbalance.untrustedPending.toInt(),
        immature: bdkbalance.immature.toInt(),
        trustedPending: bdkbalance.trustedPending.toInt(),
        spendable: bdkbalance.spendable.toInt(),
        total: bdkbalance.total.toInt(),
      );

      final w = wallet.copyWith(balance: balance.total, fullBalance: balance);

      return ((w, balance), null);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while getting balance',
          solution: 'Please try again.',
        )
      );
    }
  }
}
