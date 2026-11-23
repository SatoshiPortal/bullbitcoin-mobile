import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

import 'package:bull_logger/bull_logger.dart';

class BroadcastSellPayinUsecase {
  final Spend _spend;

  const BroadcastSellPayinUsecase(this._spend);

  @useResult
  Future<Result<String, SellFailure>> bitcoin(
    SignedBitcoinSpend signed,
  ) async => _receipt(await _spend.broadcastBitcoin(signed), 'bitcoin');

  @useResult
  Future<Result<String, SellFailure>> liquid(SignedLiquidSpend signed) async =>
      _receipt(await _spend.broadcastLiquid(signed), 'liquid');

  Result<String, SellFailure> _receipt(
    Result<SpendBroadcastReceipt, SpendFailure> result,
    String chain,
  ) => result.map((receipt) => receipt.txid).mapErr((failure) {
    const code = 'sell_payin_broadcast_failed';
    final category = switch (failure) {
      SpendDeveloperAuthorizationFailure() => 'authorization',
      SpendBroadcastConnectionFailure() => 'connection',
      SpendBroadcastRejectedFailure() => 'rejected',
      SpendAlreadyInChainFailure() => 'alreadyInChain',
      SpendBroadcastOutcomeUnknownFailure() => 'outcomeUnknown',
      SpendUnavailableFailure() => 'blocked',
      _ => 'unexpected',
    };
    log.warning('$code chain=$chain category=$category');
    return switch (failure) {
      SpendUnavailableFailure(:final busy) => SellSpendBlockedFailure(
        busy: busy,
      ),
      // Already in a block is this payin on the network: never pay again.
      SpendBroadcastOutcomeUnknownFailure() ||
      SpendAlreadyInChainFailure() => const SellPayinOutcomeUnknownFailure(),
      _ => const SellUnexpectedFailure(code),
    };
  });
}
