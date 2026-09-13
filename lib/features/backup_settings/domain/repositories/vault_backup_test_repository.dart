import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';

abstract interface class VaultBackupTestRepository {
  Future<Result<Map<VaultBackupSource, DateTime>, BackupSettingsFailure>> load(
    String descriptorId,
  );
  Future<Result<void, BackupSettingsFailure>> record(VaultBackupTest test);
}
