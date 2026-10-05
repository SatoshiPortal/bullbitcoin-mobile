import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bull_logger/bull_logger.dart';
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
    // though the UI only offers deletion for "old" seeds. An unreadable wallet
    // list refuses the deletion rather than assuming no wallet uses the seed —
    // deleting key material on a failed read is unrecoverable.
    try {
      final List<Wallet> wallets;
      switch (await _walletRepository.getWallets()) {
        case Ok(:final value):
          wallets = value;
        case Err(:final failure):
          log.warning('delete seed: ${failure.logMessage}');
          return const Err(
            SeedDeleteFailure('could not verify the remaining wallets'),
          );
      }
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
