import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Sats inbound but not yet confirmed, from swaps that have been paid but not
/// claimed.
///
/// [BoltzSwapRepository] is a shared core repository that still throws and is
/// not this change's to convert, so this use case — the first layer the wallet
/// feature owns — is the boundary for it (#1895).
class GetUnconfirmedIncomingBalanceUsecase {
  final BoltzSwapRepository _boltzSwapRepository;

  GetUnconfirmedIncomingBalanceUsecase({required this._boltzSwapRepository});

  @useResult
  Future<Result<int, WalletFailure>> execute({
    required List<String> walletIds,
  }) async {
    final List<Swap> allSwaps;
    try {
      allSwaps = await _boltzSwapRepository.getAllSwaps();
    } catch (e, st) {
      log.warning('Unconfirmed incoming balance', error: e, trace: st);
      return Err(
        WalletUnexpectedFailure('unconfirmed balance: ${e.runtimeType}'),
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
