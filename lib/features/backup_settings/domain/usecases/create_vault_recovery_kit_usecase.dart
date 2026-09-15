import 'dart:typed_data';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/vault_recovery_kit_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_kit.dart';

final class CreateVaultRecoveryKitUsecase {
  final VaultRecoveryKitRepository _repository;
  const CreateVaultRecoveryKitUsecase(this._repository);
  Future<Result<Uint8List, BackupSettingsFailure>> execute(
    VaultRecoveryKit kit,
    VaultRecoveryKitCopy copy,
  ) => _repository.create(kit, copy);
}
