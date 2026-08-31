import 'package:bb_mobile/features/bullvault/data/bullvault_record_model.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_recovery_package_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';

final class BullVaultRecordMapper {
  final BullVaultRecoveryPackageCodec _recoveryPackageCodec;

  const BullVaultRecordMapper(this._recoveryPackageCodec);

  BullVaultRecordModel toModel(BullVaultRecord entity) => BullVaultRecordModel(
    walletId: entity.walletId,
    lineageId: entity.lineageId,
    vaultGeneration: entity.vaultGeneration,
    mobileAccount: entity.mobileAccount,
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

  BullVaultRecord toEntity(BullVaultRecordModel model) => BullVaultRecord(
    walletId: model.walletId,
    lineageId: model.lineageId,
    vaultGeneration: model.vaultGeneration,
    mobileAccount: model.mobileAccount,
    birthHeight: model.birthHeight,
    recoveryPackage: _recoveryPackageCodec.decode(model.recoveryPackage),
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
