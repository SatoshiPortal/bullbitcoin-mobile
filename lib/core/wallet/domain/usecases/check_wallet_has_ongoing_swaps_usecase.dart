import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class CheckWalletHasOngoingSwapsUsecase {
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;
  final SettingsRepository _settingsRepository;

  CheckWalletHasOngoingSwapsUsecase({
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository,
       _settingsRepository = settingsRepository;

  Future<bool> execute({required String walletId}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment == Environment.testnet;

      final swapRepository =
          isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;
      final ongoingSwaps = await swapRepository.getOngoingSwaps();

      // Check if any ongoing swap is associated with this wallet
      final hasOngoingSwaps = ongoingSwaps.any((swap) {
        // Check if wallet is involved in any ongoing swap
        if (swap is LnReceiveSwap && swap.receiveWalletId == walletId) {
          return true;
        }
        if (swap is LnSendSwap && swap.sendWalletId == walletId) {
          return true;
        }
        if (swap is ChainSwap) {
          return swap.sendWalletId == walletId ||
              swap.receiveWalletId == walletId;
        }
        return false;
      });

      return hasOngoingSwaps;
    } catch (e) {
      throw CheckWalletHasOngoingSwapsException('$e');
    }
  }
}

class CheckWalletHasOngoingSwapsException implements Exception {
  final String message;

  CheckWalletHasOngoingSwapsException(this.message);
}
