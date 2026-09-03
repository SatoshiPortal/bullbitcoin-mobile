import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class UpdateBullVaultSetupUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;
  Future<void> _updateLock = Future.value();

  UpdateBullVaultSetupUsecase(this._repository, this._getWalletUsecase);

  @useResult
  Future<Result<BullVaultRecord, BullVaultFailure>> execute({
    required String walletId,
    String? completedHardwareSignerId,
    bool? recoveryPackageConfirmed,
    bool? hardwareSetupDeferred,
    bool? mobileBackupDeferred,
  }) => _serialized(() async {
    if (completedHardwareSignerId?.isEmpty == true ||
        (completedHardwareSignerId == null &&
            recoveryPackageConfirmed == null &&
            hardwareSetupDeferred == null &&
            mobileBackupDeferred == null)) {
      return const Err(BullVaultRenewalFailure());
    }
    final loaded = await _repository.getByWalletId(walletId);
    late final BullVaultRecord record;
    switch (loaded) {
      case Ok(value: final value?):
        record = value;
      case _:
        return const Err(BullVaultRenewalFailure());
    }
    if (record.status != BullVaultLifecycleStatus.pending &&
        record.status != BullVaultLifecycleStatus.active) {
      return const Err(BullVaultRenewalFailure());
    }
    final completedHardwareSignerIds = {
      ...record.completedHardwareSignerIds,
      ?completedHardwareSignerId,
    };
    var hardwareSetupComplete = record.hardwareSetupComplete;
    if (completedHardwareSignerId != null) {
      final wallet = await _getWalletUsecase.execute(walletId);
      if (wallet == null) return const Err(BullVaultRenewalFailure());
      final requiredSignerIds = {
        for (final signer in wallet.signers)
          if (signer.signer == SignerEntity.remote) signer.id,
      };
      hardwareSetupComplete = completedHardwareSignerIds.containsAll(
        requiredSignerIds,
      );
    }
    final updated = record.copyWith(
      completedHardwareSignerIds: completedHardwareSignerIds,
      hardwareSetupComplete: hardwareSetupComplete,
      hardwareSetupDeferred: hardwareSetupComplete
          ? false
          : hardwareSetupDeferred ?? record.hardwareSetupDeferred,
      recoveryPackageConfirmed:
          recoveryPackageConfirmed ?? record.recoveryPackageConfirmed,
      mobileBackupDeferred: mobileBackupDeferred ?? record.mobileBackupDeferred,
    );
    final saved = await _repository.save(updated);
    return switch (saved) {
      Ok() => Ok(updated),
      Err() => const Err(BullVaultRenewalFailure()),
    };
  });

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _updateLock;
    _updateLock = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }
}
