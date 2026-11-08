import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

/// Fingerprints of the seeds that a wallet still uses, on any network.
///
/// A seed stays in use while any wallet references it, whichever network the app currently shows, the same rule wallet deletion applies before removing a seed.
class GetSeedFingerprintsInUseUsecase {
  final WalletRepository _walletRepository;

  const GetSeedFingerprintsInUseUsecase({required this._walletRepository});

  @useResult
  Future<Result<Set<String>, WalletFailure>> execute() async =>
      (await _walletRepository.getWallets()).map(
        (wallets) => {for (final wallet in wallets) wallet.masterFingerprint},
      );
}
