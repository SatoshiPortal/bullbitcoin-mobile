import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:meta/meta.dart';

class DeleteSeedUsecase {
  final SeedRepository _seedRepository;
  final WalletRepository _walletRepository;

  const DeleteSeedUsecase({
    required this._seedRepository,
    required this._walletRepository,
  });

  @useResult
  Future<Result<void, SeedDeleteFailure>> execute(String fingerprint) async {
    // Defense-in-depth: never delete a seed that still backs a wallet, even
    // though the UI only offers deletion for "old" seeds. WalletRepository
    // still throws, so this use-case is the boundary for it.
    try {
      final wallets = await _walletRepository.getWallets();
      final hasExistingWallet = wallets.any(
        (wallet) => wallet.masterFingerprint == fingerprint,
      );
      if (hasExistingWallet) {
        log.warning(
          'Refused to delete seed $fingerprint: a wallet still uses it',
        );
        return const Err(SeedDeleteFailure());
      }
    } catch (e, st) {
      log.severe(
        message: 'Failed to verify wallets before deleting seed',
        error: e,
        trace: st,
      );
      return Err(SeedDeleteFailure(e.toString()));
    }

    return _seedRepository.delete(fingerprint);
  }
}
