import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

class SignSellPayinUsecase {
  final Spend _spend;

  const SignSellPayinUsecase(this._spend);

  @useResult
  Future<Result<SignedBitcoinSpend, SellFailure>> bitcoin(
    PreparedBitcoinSpend prepared,
  ) async => (await _spend.signBitcoin(prepared: prepared)).mapErr(_failure);

  @useResult
  Future<Result<SignedLiquidSpend, SellFailure>> liquid(
    PreparedLiquidSpend prepared,
  ) async => (await _spend.signLiquid(prepared: prepared)).mapErr(_failure);

  SellFailure _failure(SpendFailure failure) => switch (failure) {
    SpendUnavailableFailure(:final busy) => SellSpendBlockedFailure(busy: busy),
    _ => const SellUnexpectedFailure(),
  };
}
