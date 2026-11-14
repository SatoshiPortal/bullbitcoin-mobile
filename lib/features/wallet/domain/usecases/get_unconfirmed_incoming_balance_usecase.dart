import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Sats inbound but not yet confirmed, from swaps that have been paid but not
/// claimed.
class GetUnconfirmedIncomingBalanceUsecase {
  final SwapStore _swapStore;

  GetUnconfirmedIncomingBalanceUsecase({required this._swapStore});

  @useResult
  Future<Result<int, WalletFailure>> execute({
    required List<String> walletIds,
  }) async {
    final List<Swap> allSwaps;
    switch (await _swapStore.all()) {
      case Ok(:final value):
        allSwaps = value;
      case Err(:final failure):
        log.warning('Unconfirmed incoming balance (${failure.runtimeType})');
        return Err(
          WalletUnexpectedFailure(
            'unconfirmed balance: ${failure.runtimeType}',
          ),
        );
    }

    final filtered = allSwaps.where(
      (s) =>
          ((s.isChainSwap && s.isChainSwapInternal) || s.isLnReceiveSwap) &&
          (s.status == SwapStatus.paid ||
              s.status == SwapStatus.claimable ||
              s.status == SwapStatus.refundable),
    );
    final total = filtered.fold<int>(0, (sum, s) {
      final receiveable = s.receieveAmount ?? 0;
      return sum + receiveable;
    });

    return Ok(total);
  }
}
