import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';

/// Links the two lists bwk reports separately, history and coins.
abstract final class SpPaymentJoin {
  /// Flags the payments that landed on the SP sub-account, from the coins that
  /// share their txid. The UI just renders the flag.
  static List<SpPayment> markSpOutputs(
    List<SpPayment> history,
    List<SpCoin> coins,
  ) {
    final spOutputTxids = coins
        .where((coin) => coin.source == SpCoinSource.sp)
        .map((coin) => coin.outpoint.txId)
        .toSet();
    return history
        .map(
          (payment) => payment.copyWith(
            hasSpOutput: spOutputTxids.contains(payment.txid),
          ),
        )
        .toList();
  }
}
