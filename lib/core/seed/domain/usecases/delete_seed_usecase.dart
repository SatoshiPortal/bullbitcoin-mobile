import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class DeleteSeedUsecase {
  final SeedRepository _seedRepository;
  final WalletRepository _walletRepository;

  DeleteSeedUsecase({
    required SeedRepository seedRepository,
    required WalletRepository walletRepository,
  }) : _seedRepository = seedRepository,
       _walletRepository = walletRepository;

  Future<void> execute(String fingerprint) async {
    try {
      // Check if any wallet exists with this fingerprint
      final wallets = await _walletRepository.getWallets();
      final hasExistingWallet = wallets.any(
        (wallet) => wallet.masterFingerprint == fingerprint,
      );

      if (hasExistingWallet) {
        throw Exception(
          'Cannot delete seed: A wallet exists with fingerprint $fingerprint',
        );
      }

      await _seedRepository.delete(fingerprint);
    } catch (e) {
      log.severe('Failed to delete seed with fingerprint $fingerprint: $e');
      rethrow;
    }
  }
}
