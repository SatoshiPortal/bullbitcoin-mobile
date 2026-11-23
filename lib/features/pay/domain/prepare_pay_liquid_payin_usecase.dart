import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

import 'package:fees/fees.dart';

class PreparePayLiquidPayinUsecase {
  final Spend _spend;

  const PreparePayLiquidPayinUsecase(this._spend);

  @useResult
  Future<Result<PreparedLiquidSpend, PayFailure>> execute({
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
          SpendNoSpendableInputsFailure() => PayInsufficientBalanceFailure(
            requiredAmountSat: amountSat ?? 0,
          ),
          SpendUnavailableFailure(:final busy) => PaySpendBlockedFailure(
            busy: busy,
          ),
          _ => const PayUnexpectedFailure(),
        },
      );
}
