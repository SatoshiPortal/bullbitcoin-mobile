import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

class DeleteWalletUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;
  final Secrets _secrets;

  DeleteWalletUsecase({
    required this._walletRepository,
    required this._swapRepository,
    required this._secrets,
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
    // wallet derived from it is gone. Issue #2324.
    //
    // Only a wallet that signs locally holds a seed. A watch-only wallet
    // imported from a descriptor carries the key origin's fingerprint —
    // often uppercase (Sparrow, Coldcard) — but never the seed behind it,
    // so it neither owns an entry to clean up nor keeps one alive.
    // Counting it as a user, as a parsed-fingerprint compare did, left the
    // seed orphaned when the hot wallet went, and CheckDuplicateMnemonic
    // then refused to reimport it (the #2634 class). Comparing raw strings
    // trashed it when the spellings differed and kept it when they matched
    // — right or wrong by accident. Parsed, so spelling cannot matter, and
    // gated on signsLocally, so only real holders count.
    final fingerprint = Fingerprint.tryParse(wallet.masterFingerprint);
    if (wallet.signsLocally && fingerprint != null) {
      await _deleteOrphanSeed(fingerprint, walletId);
    }

    return const Ok(null);
  }

  /// Best-effort cleanup: a failure here leaves an orphan seed entry but must
  /// not fail the wallet deletion the user asked for.
  Future<void> _deleteOrphanSeed(
    Fingerprint fingerprint,
    String walletId,
  ) async {
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

    final stillUsed = remaining.any(
      (w) =>
          w.signsLocally &&
          Fingerprint.tryParse(w.masterFingerprint) == fingerprint,
    );
    if (stillUsed) return;

    // Unconditional on the package side; the "still used by a wallet" guard is this usecase's, and was applied above.
    final deleted = await _secrets.trash(fingerprint);
    if (deleted case Err(:final failure)) {
      log.warning(
        'DeleteWalletUsecase: failed to clean up seed for $walletId: '
        '${failure.logMessage}',
      );
    }
  }
}
