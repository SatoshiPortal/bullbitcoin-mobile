import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

import 'package:fees/fees.dart';

class PrepareSellLiquidPayinUsecase {
  final Spend _spend;

  const PrepareSellLiquidPayinUsecase(this._spend);

  @useResult
  Future<Result<PreparedLiquidSpend, SellFailure>> execute({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
  }) async =>
      (await _spend.prepareLiquid(
        walletId: walletId,
        address: address,
        feeRate: feeRate,
        amountSat: drain ? null : amountSat,
        drain: drain,
      )).mapErr(
        (failure) => switch (failure) {
          SpendInsufficientFundsFailure() ||
          SpendInsufficientFundsForFeesFailure() ||
          SpendNoSpendableInputsFailure() => SellInsufficientBalanceFailure(
            requiredAmountSat: amountSat ?? 0,
          ),
          SpendUnavailableFailure(:final busy) => SellSpendBlockedFailure(
            busy: busy,
          ),
          _ => const SellUnexpectedFailure(),
        },
      );
}
