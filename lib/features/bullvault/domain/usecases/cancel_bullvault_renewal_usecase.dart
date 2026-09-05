import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class CancelBullVaultRenewalUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;

  const CancelBullVaultRenewalUsecase(this._repository, this._getWalletUsecase);

  @useResult
  Future<Result<void, BullVaultFailure>> execute({
    required String previousWalletId,
    required String replacementWalletId,
  }) async {
    try {
      final replacementWallet = await _getWalletUsecase.execute(
        replacementWalletId,
        sync: true,
      );
      if (replacementWallet == null) {
        return const Err(BullVaultRenewalFailure());
      }
      if (replacementWallet.balanceSat > BigInt.zero) {
        return const Err(BullVaultRenewalHasFundsFailure());
      }
      return _repository.cancelRenewal(
        previousWalletId: previousWalletId,
        replacementWalletId: replacementWalletId,
      );
    } on Exception {
      return const Err(BullVaultRenewalFailure());
    }
  }
}
