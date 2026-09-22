import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class DeleteWalletUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;
  final SeedRepository _seedRepository;

  DeleteWalletUsecase({
    required this._walletRepository,
    required this._swapRepository,
    required this._seedRepository,
  });

  @useResult
  Future<Result<void, WalletFailure>> execute({
    required String walletId,
  }) async {
    final Wallet wallet;
    switch (await _walletRepository.getWallet(walletId)) {
      case Ok(:final value):
        wallet = value;
      case Err(:final failure):
        return Err(failure);
    }

    if (wallet.isDefault) {
      return const Err(WalletCannotDeleteDefaultFailure());
    }

    try {
      final ongoingSwaps = await _swapRepository.getOngoingSwaps(
        walletId: walletId,
      );
      if (ongoingSwaps.isNotEmpty) {
        return const Err(WalletCannotDeleteWithOngoingSwapsFailure());
      }
    } catch (e, st) {
      log.severe(message: 'DeleteWallet: swap check', error: e, trace: st);
      return Err(
        WalletUnexpectedFailure('ongoing swap check: ${e.runtimeType}'),
      );
    }

    switch (await _walletRepository.deleteWallet(walletId: walletId)) {
      case Ok():
        break;
      case Err(:final failure):
        return Err(failure);
    }

    // Clean up the seed in secure storage once no remaining wallet
    // still references it. Bitcoin and Liquid default wallets share a
    // master fingerprint, so the seed is only deleted when the last
    // wallet derived from it is gone. Watch-only wallets have an empty
    // master fingerprint and never own a seed entry. Issue #2324.
    if (wallet.masterFingerprint.isNotEmpty) {
      await _deleteOrphanSeed(wallet.masterFingerprint, walletId);
    }

    return const Ok(null);
  }

  /// Best-effort cleanup: a failure here leaves an orphan seed entry but must
  /// not fail the wallet deletion the user asked for.
  Future<void> _deleteOrphanSeed(String fingerprint, String walletId) async {
    final List<Wallet> remaining;
    switch (await _walletRepository.getWallets()) {
      case Ok(:final value):
        remaining = value;
      case Err(:final failure):
        log.warning(
          'DeleteWalletUsecase: cannot check remaining wallets for $walletId: '
          '${failure.logMessage}',
        );
        return;
    }

    if (remaining.any((w) => w.masterFingerprint == fingerprint)) return;

    final deleted = await _seedRepository.delete(fingerprint);
    if (deleted case Err(:final failure)) {
      log.warning(
        'DeleteWalletUsecase: failed to clean up seed for $walletId: '
        '${failure.logMessage}',
      );
    }
  }
}
