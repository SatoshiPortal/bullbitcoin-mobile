import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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

      // Clean up the seed in secure storage once no remaining wallet
      // still references it. Bitcoin and Liquid default wallets share a
      // master fingerprint, so the seed is only deleted when the last
      // wallet derived from it is gone. Watch-only wallets have an empty
      // master fingerprint and never own a seed entry. Issue #2324.
      if (wallet.masterFingerprint.isNotEmpty) {
        final remaining = await _walletRepository.getWallets();
        final stillUsed = remaining.any(
          (w) => w.masterFingerprint == wallet.masterFingerprint,
        );
        if (!stillUsed) {
          // Best-effort cleanup: a failure here leaves an orphan seed entry
          // but must not fail the wallet deletion the user asked for.
          final deleted = await _seedRepository.delete(
            wallet.masterFingerprint,
          );
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
