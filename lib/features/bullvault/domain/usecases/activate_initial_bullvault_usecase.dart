import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class ActivateInitialBullVaultUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;

  const ActivateInitialBullVaultUsecase(
    this._repository,
    this._getWalletUsecase,
  );

  @useResult
  Future<Result<void, BullVaultFailure>> execute({
    required String walletId,
    required bool hardwareSetupDeferred,
    required bool hasMobileBackup,
    required bool mobileBackupDeferred,
  }) async {
    final loaded = await _repository.getByWalletId(walletId);
    late final BullVaultRecord record;
    switch (loaded) {
      case Ok(value: final value?):
        record = value;
      case _:
        return const Err(BullVaultCreationFailure());
    }
    if (record.vaultGeneration != 0 || !record.recoveryPackageConfirmed) {
      return const Err(BullVaultCreationFailure());
    }
    if (record.status == BullVaultLifecycleStatus.active) {
      return const Ok(null);
    }
    if (record.status != BullVaultLifecycleStatus.pending) {
      return const Err(BullVaultCreationFailure());
    }
    final Wallet? wallet;
    try {
      wallet = await _getWalletUsecase.execute(walletId);
    } on Exception {
      return const Err(BullVaultCreationFailure());
    }
    if (wallet == null) return const Err(BullVaultCreationFailure());
    final requiredSignerIds = {
      for (final signer in wallet.signers)
        if (signer.signer == SignerEntity.remote) signer.id,
    };
    final hardwareSetupComplete = record.completedHardwareSignerIds.containsAll(
      requiredSignerIds,
    );
    if ((!hardwareSetupComplete && !hardwareSetupDeferred) ||
        (record.mobileAccount != null &&
            !hasMobileBackup &&
            !mobileBackupDeferred)) {
      return const Err(BullVaultCreationFailure());
    }

    return _repository.activateInitial(
      record.copyWith(
        hardwareSetupComplete: hardwareSetupComplete,
        hardwareSetupDeferred: hardwareSetupDeferred,
        mobileBackupDeferred: mobileBackupDeferred,
      ),
    );
  }
}
