import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class GetUnconfirmedIncomingBalanceUsecase {
  final SettingsRepository _settingsRepository;
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;

  GetUnconfirmedIncomingBalanceUsecase({
    required SettingsRepository settingsRepository,
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
  }) : _settingsRepository = settingsRepository,
       _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository;

  Future<int> execute({required List<String> walletIds}) async {
    final settings = await _settingsRepository.fetch();
    final environment = settings.environment;
    final swapRepository =
        environment.isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;

    final allSwaps = await swapRepository.getAllSwaps(
      isTestnet: environment.isTestnet,
    );

    final filtered = allSwaps.where(
      (s) =>
          ((s.isChainSwap && s.isChainSwapInternal) || s.isLnReceiveSwap) &&
          (s.status == SwapStatus.paid ||
              s.status == SwapStatus.claimable ||
              s.status == SwapStatus.refundable),
    );
    // final uniqueSwaps = <String, Swap>{};
    // for (final swap in filtered) {
    //   uniqueSwaps[swap.id] = swap;
    // }
    final total = filtered.fold<int>(0, (sum, s) {
      final fees = s.fees?.totalFees(s.amountSat) ?? 0;
      return sum + (s.amountSat - fees);
    });

    // User balance updates on 0 conf bitcoin tx so no need to add untrusted pending sat

    // int totalUntrustedPendingSat = 0;
    // for (final walletId in walletIds) {
    //   final balances = await _walletRepository.getWalletBalances(
    //     walletId: walletId,
    //   );
    //   totalUntrustedPendingSat += balances.untrustedPendingSat;
    // }

    return total;
  }
}
