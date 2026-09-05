import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class DeleteWalletUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;
  final SeedRepository _seedRepository;

  DeleteWalletUsecase({
    required this._walletRepository,
    required this._swapRepository,
    required this._seedRepository,
  });

  Future<void> execute({required String walletId}) async {
    try {
      final wallet = await _walletRepository.getWallet(walletId);
      if (wallet == null) {
        throw WalletError.notFound(walletId);
      }

      if (wallet.isDefault) {
        throw const WalletError.cannotDeleteDefaultWallet();
      }

      final ongoingSwaps = await _swapRepository.getOngoingSwaps(
        walletId: walletId,
      );
      if (ongoingSwaps.isNotEmpty) {
        throw const WalletError.cannotDeleteWalletWithOngoingSwaps();
      }

      await _walletRepository.deleteWallet(walletId: walletId);

      // Clean up locally held seeds once no remaining wallet references them.
      final localFingerprints = wallet.localMasterFingerprints.toSet();
      if (localFingerprints.isNotEmpty) {
        final remainingWallets = await _walletRepository.getWallets();
        for (final fingerprint in localFingerprints) {
          final stillUsed = remainingWallets.any(
            (remaining) =>
                remaining.localMasterFingerprints.contains(fingerprint),
          );
          if (stillUsed) continue;

          // Best-effort cleanup: a failure here leaves an orphan seed entry
          // but must not fail the wallet deletion the user asked for.
          final deleted = await _seedRepository.delete(fingerprint);
          if (deleted case Err(:final failure)) {
            log.warning(
              'DeleteWalletUsecase: failed to clean up seed for $walletId: '
              '${failure.logMessage}',
            );
          }
        }
      }
    } on WalletError {
      rethrow;
    } catch (e) {
      throw WalletError.unexpected('Failed to delete wallet: $e');
    }
  }
}
