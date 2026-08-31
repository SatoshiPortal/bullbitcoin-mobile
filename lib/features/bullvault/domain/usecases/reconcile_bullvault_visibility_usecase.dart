import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_renewal_usecase.dart';

class ReconcileBullVaultVisibilityUsecase {
  final GetWalletsUsecase _getWalletsUsecase;
  final BullVaultRepository _repository;
  final ResumeBullVaultOnboardingUsecase _resumeOnboardingUsecase;
  final ResumeBullVaultRenewalUsecase _resumeRenewalUsecase;

  const ReconcileBullVaultVisibilityUsecase(
    this._getWalletsUsecase,
    this._repository,
    this._resumeOnboardingUsecase,
    this._resumeRenewalUsecase,
  );

  Future<Result<void, BullVaultFailure>> execute() async {
    late final List<Wallet> wallets;
    try {
      wallets = await _getWalletsUsecase.execute(includeHidden: true);
    } on NoWalletsFoundException {
      return const Ok(null);
    } on Exception {
      return const Err(BullVaultRenewalFailure());
    }

    BullVaultFailure? firstFailure;
    for (final wallet in wallets.where((wallet) => wallet.isBitcoin)) {
      final recordResult = await _repository.getByWalletId(wallet.id);
      final BullVaultRecord record;
      switch (recordResult) {
        case Ok(value: final value?):
          record = value;
        case Ok(value: null):
          continue;
        case Err(:final failure):
          firstFailure ??= failure;
          continue;
      }
      final repair =
          record.vaultGeneration == 0 &&
              (record.status == BullVaultLifecycleStatus.pending ||
                  record.status == BullVaultLifecycleStatus.activating)
          ? await _resumeOnboardingUsecase.execute(
              wallet.network,
              walletId: wallet.id,
            )
          : await _resumeRenewalUsecase.execute(wallet.id);
      if (repair case Err(:final failure)) {
        firstFailure ??= failure;
      }
    }
    return firstFailure == null ? const Ok(null) : Err(firstFailure);
  }
}
