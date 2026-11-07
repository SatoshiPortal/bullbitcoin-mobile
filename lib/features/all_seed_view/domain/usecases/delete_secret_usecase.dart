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
      switch (await _walletRepository.getWallets()) {
        // Only a wallet that signs locally holds this seed; a watch-only wallet
        // with the same origin fingerprint does not, whatever its spelling.
        // Same rule as DeleteWalletUsecase and ImportWalletUsecase.
        case Ok(value: final wallets)
            when wallets.any(
              (w) =>
                  w.signsLocally &&
                  Fingerprint.tryParse(w.masterFingerprint) == id,
            ):
          log.warning('Seed delete refused reason=referenced');
          return const Err(
            AllSeedViewDeleteFailure('a wallet still uses this secret'),
          );
        case Ok():
          break;
        case Err():
          // An unreadable wallet list refuses the deletion rather than
          // assuming no wallet uses the secret — deleting key material on a
          // failed read is unrecoverable.
          log.warning('Seed delete refused reason=references_unavailable');
          return const Err(
            AllSeedViewDeleteFailure('could not verify wallets'),
          );
      }
    } on Exception {
      log.warning('Seed delete refused reason=references_unavailable');
      return const Err(AllSeedViewDeleteFailure('could not verify wallets'));
    }
    final result = await _secrets.trash(id);
    if (result is Ok) log.fine('Seed deleted source=manual');
    // The keystore boundary owns storage failures.
    return result.mapErr((f) => AllSeedViewDeleteFailure(f.logMessage));
  }
}
