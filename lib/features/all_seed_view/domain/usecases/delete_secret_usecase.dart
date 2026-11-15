import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show SeedReferences;
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
  final SeedReferences _seedReferences;

  const DeleteSecretUsecase({
    required this._secrets,
    required this._seedReferences,
  });

  @useResult
  Future<Result<void, AllSeedViewFailure>> execute(Fingerprint id) async {
    try {
      switch (await _seedReferences.getCustodyFingerprints()) {
        // Only a wallet that signs locally holds this seed; a watch-only wallet
        // with the same origin fingerprint does not, whatever its spelling.
        // Same rule as DeleteWalletUsecase and ImportWalletUsecase.
        case Ok(value: final fingerprints) when fingerprints.contains(id):
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
