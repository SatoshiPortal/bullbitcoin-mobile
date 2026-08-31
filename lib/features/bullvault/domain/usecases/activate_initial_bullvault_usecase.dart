import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_wallet_hidden_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class ActivateInitialBullVaultUsecase {
  static final Map<String, Future<void>> _activationLocks = {};

  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;
  final SetWalletHiddenUsecase _setWalletHiddenUsecase;

  const ActivateInitialBullVaultUsecase(
    this._repository,
    this._getWalletUsecase,
    this._setWalletHiddenUsecase,
  );

  @useResult
  Future<Result<void, BullVaultFailure>> execute({
    required String walletId,
    required bool hardwareSetupDeferred,
    required bool hasMobileBackup,
    required bool mobileBackupDeferred,
  }) => _serialized(
    walletId,
    () => _execute(
      walletId: walletId,
      hardwareSetupDeferred: hardwareSetupDeferred,
      hasMobileBackup: hasMobileBackup,
      mobileBackupDeferred: mobileBackupDeferred,
    ),
  );

  Future<Result<void, BullVaultFailure>> _execute({
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
    if (record.status != BullVaultLifecycleStatus.pending &&
        record.status != BullVaultLifecycleStatus.activating) {
      return const Err(BullVaultCreationFailure());
    }
    final wallet = await _getWalletUsecase.execute(walletId);
    if (wallet == null) return const Err(BullVaultCreationFailure());
    final requiredSignerIds = {
      for (final signer in wallet.signers)
        if (signer.signer != SignerEntity.local) signer.id,
    };
    final hardwareSetupComplete = record.completedHardwareSignerIds.containsAll(
      requiredSignerIds,
    );
    final effectiveHardwareSetupDeferred =
        record.status == BullVaultLifecycleStatus.activating
        ? record.hardwareSetupDeferred
        : hardwareSetupDeferred;
    final effectiveMobileBackupDeferred =
        record.status == BullVaultLifecycleStatus.activating
        ? record.mobileBackupDeferred
        : mobileBackupDeferred;
    if ((!hardwareSetupComplete && !effectiveHardwareSetupDeferred) ||
        (!hasMobileBackup && !effectiveMobileBackupDeferred)) {
      return const Err(BullVaultCreationFailure());
    }

    final activating = record.status == BullVaultLifecycleStatus.activating
        ? record
        : record.copyWith(
            status: BullVaultLifecycleStatus.activating,
            hardwareSetupComplete: hardwareSetupComplete,
            hardwareSetupDeferred: effectiveHardwareSetupDeferred,
            mobileBackupDeferred: effectiveMobileBackupDeferred,
          );
    if (record.status == BullVaultLifecycleStatus.pending) {
      if (await _repository.save(activating) case Err(:final failure)) {
        return Err(failure);
      }
    }
    try {
      await _setWalletHiddenUsecase.execute(
        walletId: walletId,
        isHidden: false,
      );
      final active = activating.copyWith(
        status: BullVaultLifecycleStatus.active,
      );
      if (await _repository.save(active) case Err(:final failure)) {
        throw _ActivationPersistenceException(failure);
      }
      return const Ok(null);
    } on Exception {
      try {
        await _setWalletHiddenUsecase.execute(
          walletId: walletId,
          isHidden: true,
        );
        switch (await _repository.save(record)) {
          case Ok():
            break;
          case Err():
            throw StateError('Could not restore BullVault setup state');
        }
      } on Exception {
        // The activating record remains a durable retry marker.
      }
      return const Err(BullVaultCreationFailure());
    }
  }

  Future<T> _serialized<T>(String walletId, Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _activationLocks[walletId] ?? Future.value();
    final current = completer.future;
    _activationLocks[walletId] = current;
    return previous.catchError((_) {}).then((_) => action()).whenComplete(() {
      completer.complete();
      if (identical(_activationLocks[walletId], current)) {
        _activationLocks.remove(walletId);
      }
    });
  }
}

final class _ActivationPersistenceException implements Exception {
  final BullVaultFailure failure;

  const _ActivationPersistenceException(this.failure);
}
