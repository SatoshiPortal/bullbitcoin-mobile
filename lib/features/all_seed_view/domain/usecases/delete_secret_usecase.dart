import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Deletes a stored secret — unless a wallet still uses it.
///
/// The guard is this usecase's, on purpose: `Secrets.trash` is unconditional because the package does not know what a wallet is, and must not learn. This is where the two meet.
class DeleteSecretUsecase {
  final Secrets _secrets;
  final WalletRepository _walletRepository;

  const DeleteSecretUsecase({
    required Secrets secrets,
    required WalletRepository walletRepository,
  }) : this._(secrets, walletRepository);

  const DeleteSecretUsecase._(this._secrets, this._walletRepository);

  @useResult
  Future<Result<void, AllSeedViewFailure>> execute(Fingerprint id) async {
    try {
      final wallets = await _walletRepository.getWallets();
      // Only a wallet that signs locally holds this seed; a watch-only wallet
      // with the same origin fingerprint does not, whatever its spelling.
      // Same rule as DeleteWalletUsecase and ImportWalletUsecase.
      final stillUsed = wallets.any(
        (w) =>
            w.signsLocally && Fingerprint.tryParse(w.masterFingerprint) == id,
      );
      if (stillUsed) {
        log.warning('Refused to delete secret $id: a wallet still uses it');
        return const Err(
          AllSeedViewDeleteFailure('a wallet still uses this secret'),
        );
      }
    } catch (e, st) {
      // If the wallets cannot be listed, nothing is deleted: a guard that cannot be evaluated has failed.
      log.severe(
        message: 'Failed to verify wallets before deleting secret',
        error: e,
        trace: st,
      );
      return const Err(AllSeedViewDeleteFailure('could not verify wallets'));
    }
    return (await _secrets.trash(
      id,
    )).mapErr((f) => AllSeedViewDeleteFailure(f.logMessage));
  }
}
