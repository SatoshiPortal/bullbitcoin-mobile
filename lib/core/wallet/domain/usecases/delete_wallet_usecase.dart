import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class DeleteWalletUsecase {
  final WalletRepository _walletRepository;
  final BoltzSwapRepository _swapRepository;
  final Secrets _secrets;

  DeleteWalletUsecase({
    required this._walletRepository,
    required this._swapRepository,
    required this._secrets,
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
        final remaining = await _walletRepository.getWallets();
        final stillUsed = remaining.any(
          (w) =>
              w.signsLocally &&
              Fingerprint.tryParse(w.masterFingerprint) == fingerprint,
        );
        if (!stillUsed) {
          // Best-effort cleanup: a failure here leaves an orphan seed entry
          // but must not fail the wallet deletion the user asked for.
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
    } on WalletError {
      rethrow;
    } catch (e) {
      throw WalletError.unexpected('Failed to delete wallet: $e');
    }
  }
}
