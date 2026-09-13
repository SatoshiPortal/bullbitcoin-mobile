import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';

class UpdateBullVaultSetupUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;
  final BitcoinDescriptorPort _descriptors;
  Future<void> _updateLock = Future.value();

  UpdateBullVaultSetupUsecase(
    this._repository,
    this._getWalletUsecase,
    this._descriptors,
  );

  Future<Result<BullVaultRecord?, BullVaultFailure>> importRecoveryFile(
    String walletId,
  ) async {
    final file = await _repository.pickRecoveryFile();
    return switch (file) {
      Err(:final failure) => Err(failure),
      Ok(value: null) => const Ok(null),
      Ok(:final value) => execute(
        walletId: walletId,
        recoveryPackageConfirmed: true,
        descriptorReadBack: value,
      ),
    };
  }

  @useResult
  Future<Result<BullVaultRecord, BullVaultFailure>> execute({
    required String walletId,
    String? completedHardwareSignerId,
    bool? recoveryPackageConfirmed,
    String? descriptorReadBack,
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
    if (recoveryPackageConfirmed == true) {
      if (descriptorReadBack == null ||
          descriptorReadBack.isEmpty ||
          descriptorReadBack.length > 128 * 1024) {
        return const Err(BullVaultInvalidRecoveryFailure());
      }
      try {
        var candidate = descriptorReadBack;
        final policy = record.recoveryPackage.policy;
        if (candidate.trimLeft().startsWith('{')) {
          final decoded = _repository.decodeRecoveryPackage(candidate);
          if (decoded case Ok(
            :final value,
          ) when value.policy.network == policy.network) {
            candidate = value.policy.descriptor;
          } else {
            return const Err(BullVaultInvalidRecoveryFailure());
          }
        }
        final parsed = _descriptors.parseBitcoinDescriptor(
          descriptor: candidate,
          network: policy.network,
        );
        final expected = _descriptors.parseBitcoinDescriptor(
          descriptor: policy.descriptor,
          network: policy.network,
        );
        if (parsed.descriptor != expected.descriptor) {
          return const Err(BullVaultInvalidRecoveryFailure());
        }
      } on Exception {
        return const Err(BullVaultInvalidRecoveryFailure());
      }
    }
    final completedHardwareSignerIds = {
      ...record.completedHardwareSignerIds,
      ?completedHardwareSignerId,
    };
    var hardwareSetupComplete = record.hardwareSetupComplete;
    if (completedHardwareSignerId != null) {
      final Wallet? wallet;
      try {
        wallet = await _getWalletUsecase.execute(walletId);
      } on Exception {
        return const Err(BullVaultRenewalFailure());
      }
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
