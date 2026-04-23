import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class GetUnconfirmedIncomingBalanceUsecase {
  final BoltzSwapRepository _boltzSwapRepository;

  GetUnconfirmedIncomingBalanceUsecase({
    required BoltzSwapRepository boltzSwapRepository,
  }) : _boltzSwapRepository = boltzSwapRepository;

  Future<int> execute({required List<String> walletIds}) async {
    final allSwaps = await _boltzSwapRepository.getAllSwaps();

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

    return total;
  }
}
