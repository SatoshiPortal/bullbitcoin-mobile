import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:lwk_dart/lwk_dart.dart' as lwk;

class LWKBalance {
  Future<((Wallet, Balance)?, Err?)> getLiquidBalance({
    required lwk.Wallet lwkWallet,
    required Wallet wallet,
  }) async {
    try {
      final assetToPick = wallet.network == BBNetwork.Mainnet
          ? lwk.lBtcAssetId
          : lwk.lTestAssetId;
      final balances = await lwkWallet.balances();
      final finalBalance = balances
          .where((e) => e.assetId == assetToPick)
          .map((e) => e.value)
          .first;

      final balance = Balance(
        confirmed: finalBalance,
        untrustedPending: 0,
        immature: 0,
        trustedPending: 0,
        spendable: finalBalance,
        total: finalBalance,
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
