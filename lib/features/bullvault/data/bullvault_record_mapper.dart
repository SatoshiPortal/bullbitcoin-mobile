import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_model.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_recovery_package_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';

final class BullVaultRecordMapper {
  final BullVaultRecoveryPackageCodec _recoveryPackageCodec;

  const BullVaultRecordMapper(this._recoveryPackageCodec);

  BullVaultRecordModel toModel(BullVaultRecord entity) => BullVaultRecordModel(
    walletId: entity.walletId,
    lineageId: entity.lineageId,
    vaultGeneration: entity.vaultGeneration,
    mobileAccount: entity.mobileAccount,
    mobileSeedFingerprint: entity.mobileSeedFingerprint,
    mobilePassphraseRequired:
        entity.recoveryPackage.policy.everydayKey.accountKey.requiresPassphrase,
    birthHeight: entity.birthHeight,
    recoveryPackage: _recoveryPackageCodec.encode(entity.recoveryPackage),
    previousVaultId: entity.previousVaultId,
    successorWalletId: entity.successorWalletId,
    status: entity.status.name,
    hardwareSetupComplete: entity.hardwareSetupComplete,
    hardwareSetupDeferred: entity.hardwareSetupDeferred,
    completedHardwareSignerIds: entity.completedHardwareSignerIds.toList()
      ..sort(),
    recoveryPackageConfirmed: entity.recoveryPackageConfirmed,
    mobileBackupDeferred: entity.mobileBackupDeferred,
    createdAt: entity.createdAt.toUtc().toIso8601String(),
  );

  BullVaultRecord toEntity(BullVaultRecordModel model) {
    final decodedPackage = _recoveryPackageCodec.decode(model.recoveryPackage);
    final restoredPolicy = model.mobileAccount == null
        ? decodedPackage.policy
        : decodedPackage.policy.withEverydayOwnership(
            SignerEntity.local,
            requiresPassphrase: model.mobilePassphraseRequired,
          );
    return BullVaultRecord(
      walletId: model.walletId,
      lineageId: model.lineageId,
      vaultGeneration: model.vaultGeneration,
      mobileAccount: model.mobileAccount,
      mobileSeedFingerprint: model.mobileSeedFingerprint,
      birthHeight: model.birthHeight,
      recoveryPackage: BullVaultRecoveryPackage(
        previousVaultId: decodedPackage.previousVaultId,
        policy: restoredPolicy,
      ),
      previousVaultId: model.previousVaultId,
      successorWalletId: model.successorWalletId,
      status: BullVaultLifecycleStatus.values.byName(model.status),
      hardwareSetupComplete: model.hardwareSetupComplete,
      hardwareSetupDeferred: model.hardwareSetupDeferred,
      completedHardwareSignerIds: model.completedHardwareSignerIds.toSet(),
      recoveryPackageConfirmed: model.recoveryPackageConfirmed,
      mobileBackupDeferred: model.mobileBackupDeferred,
      createdAt: DateTime.parse(model.createdAt).toUtc(),
    );
  }
}
