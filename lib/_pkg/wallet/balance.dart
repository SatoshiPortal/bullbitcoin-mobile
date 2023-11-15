import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class WalletBalance {
  Future<((Wallet, Balance)?, Err?)> getBalance({
    required bdk.Wallet bdkWallet,
    required Wallet wallet,
  }) async {
    try {
      final bdkbalance = await bdkWallet.getBalance();

      final balance = Balance(
        confirmed: bdkbalance.confirmed,
        untrustedPending: bdkbalance.untrustedPending,
        immature: bdkbalance.immature,
        trustedPending: bdkbalance.trustedPending,
        spendable: bdkbalance.spendable,
        total: bdkbalance.total,
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
