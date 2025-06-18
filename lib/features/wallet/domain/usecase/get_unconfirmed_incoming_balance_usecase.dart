import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class GetUnconfirmedIncomingBalanceUsecase {
  final SettingsRepository _settingsRepository;
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;
  final WalletRepository _walletRepository;

  GetUnconfirmedIncomingBalanceUsecase({
    required SettingsRepository settingsRepository,
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
    required WalletRepository walletRepository,
  }) : _settingsRepository = settingsRepository,
       _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository,
       _walletRepository = walletRepository;

  Future<int> execute({required List<String> walletIds}) async {
    final settings = await _settingsRepository.fetch();
    final environment = settings.environment;
    final swapRepository =
        environment.isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;

    final allSwaps = <Swap>[];
    for (final walletId in walletIds) {
      final swaps = await swapRepository.getAllSwaps(walletId: walletId);
      allSwaps.addAll(swaps);
    }

    final filtered = allSwaps.where(
      (s) =>
          ((s.isChainSwap && s.isChainSwapInternal) || s.isLnReceiveSwap) &&
          (s.status == SwapStatus.paid ||
              s.status == SwapStatus.claimable ||
              s.status == SwapStatus.refundable),
    );
    final uniqueSwaps = <String, Swap>{};
    for (final swap in filtered) {
      uniqueSwaps[swap.id] = swap;
    }
    final total = uniqueSwaps.values.fold<int>(0, (sum, s) {
      final fees = s.fees?.totalFees(s.amountSat) ?? 0;
      return sum + (s.amountSat - fees);
    });

    int totalUntrustedPendingSat = 0;
    for (final walletId in walletIds) {
      final balances = await _walletRepository.getWalletBalances(
        walletId: walletId,
      );
      totalUntrustedPendingSat += balances.untrustedPendingSat;
    }

    return total + totalUntrustedPendingSat;
  }
}
