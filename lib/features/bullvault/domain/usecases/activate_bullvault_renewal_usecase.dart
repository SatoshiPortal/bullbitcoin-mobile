import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_wallet_hidden_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class ActivateBullVaultRenewalUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;
  final SetWalletHiddenUsecase _setWalletHiddenUsecase;

  const ActivateBullVaultRenewalUsecase(
    this._repository,
    this._getWalletUsecase,
    this._setWalletHiddenUsecase,
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
    late BullVaultRecord replacement;
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
      try {
        await _setWalletHiddenUsecase.execute(
          walletId: replacement.walletId,
          isHidden: false,
        );
        await _setWalletHiddenUsecase.execute(
          walletId: previous.walletId,
          isHidden: true,
        );
        return const Ok(null);
      } on Exception {
        return const Err(BullVaultRenewalFailure());
      }
    }
    final replacementWallet = await _getWalletUsecase.execute(
      replacement.walletId,
    );
    if (replacementWallet == null) {
      return const Err(BullVaultRenewalFailure());
    }
    final requiredSignerIds = {
      for (final signer in replacementWallet.signers)
        if (signer.signer != SignerEntity.local) signer.id,
    };
    if ((replacement.status != BullVaultLifecycleStatus.pending &&
            replacement.status != BullVaultLifecycleStatus.activating) ||
        !replacement.recoveryPackageConfirmed ||
        !replacement.completedHardwareSignerIds.containsAll(
          requiredSignerIds,
        )) {
      return const Err(BullVaultRenewalFailure());
    }
    replacement = replacement.copyWith(hardwareSetupComplete: true);
    if (replacement.status == BullVaultLifecycleStatus.pending) {
      replacement = replacement.copyWith(
        status: BullVaultLifecycleStatus.activating,
      );
      if (await _repository.save(replacement) case Err(:final failure)) {
        return Err(failure);
      }
    }
    try {
      await _setWalletHiddenUsecase.execute(
        walletId: replacement.walletId,
        isHidden: false,
      );
      try {
        await _setWalletHiddenUsecase.execute(
          walletId: previous.walletId,
          isHidden: true,
        );
      } on Exception {
        await _setWalletHiddenUsecase.execute(
          walletId: replacement.walletId,
          isHidden: true,
        );
        rethrow;
      }
    } on Exception {
      return const Err(BullVaultRenewalFailure());
    }
    final result = await _repository.activateRenewal(
      previous: previous,
      replacement: replacement,
    );
    if (result case Err()) {
      final latestPrevious = await _repository.getByWalletId(previous.walletId);
      final latestReplacement = await _repository.getByWalletId(
        replacement.walletId,
      );
      if (latestPrevious case Ok(
        value: final currentPrevious?,
      ) when latestReplacement is Ok<BullVaultRecord?, BullVaultFailure>) {
        final currentReplacement = latestReplacement.value;
        if (currentPrevious.status == BullVaultLifecycleStatus.migrating &&
            currentPrevious.successorWalletId == replacement.walletId &&
            currentReplacement?.status == BullVaultLifecycleStatus.active) {
          return const Ok(null);
        }
      }
      try {
        await _setWalletHiddenUsecase.execute(
          walletId: previous.walletId,
          isHidden: false,
        );
        await _setWalletHiddenUsecase.execute(
          walletId: replacement.walletId,
          isHidden: true,
        );
        final pending = replacement.copyWith(
          status: BullVaultLifecycleStatus.pending,
        );
        if (await _repository.save(pending) case Err()) {
          throw StateError('Could not restore BullVault renewal state');
        }
      } on Exception {
        return const Err(BullVaultRenewalFailure());
      }
    }
    return result;
  }
}
