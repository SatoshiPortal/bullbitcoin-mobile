import 'dart:typed_data';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_kit.dart';

abstract interface class VaultRecoveryKitRepository {
  Future<Result<Uint8List, BackupSettingsFailure>> create(
    VaultRecoveryKit kit,
    VaultRecoveryKitCopy copy,
  );
}
