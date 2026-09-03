import 'package:bb_mobile/features/wallet/domain/seed_reference_port.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:secrets/secrets.dart';

class DeleteWalletUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;
  final Secrets _secrets;
  final SeedReferences _seedReferences;

  DeleteWalletUsecase({
    required this._walletRepository,
    required this._swapRepository,
    required this._secrets,
    required this._seedReferences,
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
      log.severe(
        message: 'Wallet delete failed stage=swap reason=storage',
        error: 'storage',
        trace: st,
      );
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

    for (final value in wallet.localSeedFingerprints.toSet()) {
      final fingerprint = Fingerprint.tryParse(value);
      if (fingerprint != null) await _deleteOrphanSeed(fingerprint);
    }

    return const Ok(null);
  }

  /// Best-effort cleanup: a failure here leaves an orphan seed entry but must
  /// not fail the wallet deletion the user asked for.
  Future<void> _deleteOrphanSeed(Fingerprint fingerprint) async {
    final Set<Fingerprint> remaining;
    switch (await _seedReferences.getCustodyFingerprints()) {
      case Ok(:final value):
        remaining = value;
      case Err():
        log.warning('Seed cleanup failed reason=references_unavailable');
        return;
    }

    if (remaining.contains(fingerprint)) {
      log.fine('Seed cleanup skipped reason=referenced');
      return;
    }

    // Unconditional on the package side; the "still used by a wallet" guard
    // is this usecase's, and was applied above.
    final deleted = await _secrets.trash(fingerprint);
    // The keystore boundary owns storage failures.
    if (deleted is Ok) log.fine('Seed deleted source=wallet_cleanup');
  }
}
