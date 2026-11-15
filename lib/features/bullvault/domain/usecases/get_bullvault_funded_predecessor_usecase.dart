import 'package:primitives/primitives.dart' show Result, Ok, Err;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';

class GetBullVaultFundedPredecessorUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;

  const GetBullVaultFundedPredecessorUsecase(
    this._repository,
    this._getWalletUsecase,
  );

  Future<Result<String?, BullVaultFailure>> execute(
    List<Wallet> wallets,
  ) async {
    final destinations = await _repository.getMigrationDestinations({
      for (final wallet in wallets)
        if (wallet.isBitcoin) wallet.id,
    });
    switch (destinations) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        try {
          for (final entry in value.entries) {
            final previous = await _getWalletUsecase.execute(entry.key);
            if (previous == null) continue;
            final balance = previous.balanceSat;
            if (balance == null) return const Err(BullVaultRenewalFailure());
            if (balance > BigInt.zero) {
              return Ok(entry.value);
            }
          }
          return const Ok(null);
        } on Exception {
          return const Err(BullVaultRenewalFailure());
        }
    }
  }
}
