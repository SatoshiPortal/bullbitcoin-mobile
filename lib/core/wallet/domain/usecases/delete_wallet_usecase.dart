import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class DeleteWalletUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final BoltzSwapRepository _mainnetSwapRepository;
  final BoltzSwapRepository _testnetSwapRepository;

  DeleteWalletUsecase({
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
    required BoltzSwapRepository mainnetSwapRepository,
    required BoltzSwapRepository testnetSwapRepository,
  }) : _walletRepository = walletRepository,
       _settingsRepository = settingsRepository,
       _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository;

  Future<void> execute({required String walletId}) async {
    try {
      final wallet = await _walletRepository.getWallet(walletId);
      if (wallet == null) {
        throw WalletError.notFound(walletId);
      }

      // Check if it's a default wallet - default wallets cannot be deleted
      if (wallet.isDefault) {
        throw const WalletError.cannotDeleteDefaultWallet();
      }

      // Check if wallet has ongoing swaps
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment == Environment.testnet;

      final swapRepository =
          isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;
      final ongoingSwaps = await swapRepository.getOngoingSwaps(
        walletId: walletId,
      );
      if (ongoingSwaps.isNotEmpty) {
        throw const WalletError.cannotDeleteWalletWithOngoingSwaps();
      }

      // Proceed with deletion
      await _walletRepository.deleteWallet(walletId: walletId);
    } on WalletError {
      rethrow;
    } catch (e) {
      throw WalletError.unexpected('Failed to delete wallet: $e');
    }
  }
}
