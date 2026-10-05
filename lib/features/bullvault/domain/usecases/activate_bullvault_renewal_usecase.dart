import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class ActivateBullVaultRenewalUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;

  const ActivateBullVaultRenewalUsecase(
    this._repository,
    this._getWalletUsecase,
  );

  @useResult
  Future<Result<void, BullVaultFailure>> execute({
    required String previousWalletId,
    required String replacementWalletId,
  }) async {
    final previousResult = await _repository.getByWalletId(previousWalletId);
    final replacementResult = await _repository.getByWalletId(
      replacementWalletId,
    );
    late final BullVaultRecord previous;
    late final BullVaultRecord replacement;
    switch (previousResult) {
      case Ok(value: final record?):
        previous = record;
      case _:
        return const Err(BullVaultRenewalFailure());
    }
    switch (replacementResult) {
      case Ok(value: final record?):
        replacement = record;
      case _:
        return const Err(BullVaultRenewalFailure());
    }
    if (previous.status == BullVaultLifecycleStatus.migrating &&
        previous.successorWalletId == replacement.walletId &&
        replacement.status == BullVaultLifecycleStatus.active) {
      return const Ok(null);
    }
    final Wallet? replacementWallet;
    try {
      replacementWallet = await _getWalletUsecase.execute(replacement.walletId);
    } on Exception {
      return const Err(BullVaultRenewalFailure());
    }
    if (replacementWallet == null) {
      return const Err(BullVaultRenewalFailure());
    }
    final requiredSignerIds = {
      for (final signer in replacementWallet.signers)
        if (signer.signer == SignerEntity.remote) signer.id,
    };
    if (replacement.status != BullVaultLifecycleStatus.pending ||
        !replacement.recoveryPackageConfirmed ||
        !replacement.completedHardwareSignerIds.containsAll(
          requiredSignerIds,
        )) {
      return const Err(BullVaultRenewalFailure());
    }
    return _repository.activateRenewal(
      previous: previous,
      replacement: replacement.copyWith(hardwareSetupComplete: true),
    );
  }
}
