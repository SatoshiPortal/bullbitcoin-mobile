import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';

abstract interface class VaultBackupTestRepository {
  /// The applicable date per source for this descriptor.
  ///
  /// A receipt bound to another [endpoint] is not applicable: the server in
  /// force now has never been asked for this descriptor, and showing the old
  /// server's date beside it would claim a route that was never tested.
  Future<Result<Map<VaultBackupSource, DateTime>, BackupSettingsFailure>> load(
    String descriptorId, {
    required String endpoint,
  });
  Future<Result<void, BackupSettingsFailure>> record(VaultBackupTest test);
}
