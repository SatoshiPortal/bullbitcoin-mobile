import 'package:bull_exchange/src/pay/domain/pay_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

class SignPayPayinUsecase {
  final Spend _spend;

  const SignPayPayinUsecase(this._spend);

  @useResult
  Future<Result<SignedBitcoinSpend, PayFailure>> bitcoin(
    PreparedBitcoinSpend prepared,
  ) async => (await _spend.signBitcoin(prepared: prepared)).mapErr(_failure);

  @useResult
  Future<Result<SignedLiquidSpend, PayFailure>> liquid(
    PreparedLiquidSpend prepared,
  ) async => (await _spend.signLiquid(prepared: prepared)).mapErr(_failure);

  PayFailure _failure(SpendFailure failure) => switch (failure) {
    SpendUnavailableFailure(:final busy) => PaySpendBlockedFailure(busy: busy),
    _ => const PayUnexpectedFailure(),
  };
}
