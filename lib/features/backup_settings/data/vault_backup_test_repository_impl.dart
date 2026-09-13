import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/vault_backup_test_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One independently written preference per descriptor/source, not a shared
/// read-modify-write JSON object that can lose another source's result.
final class VaultBackupTestRepositoryImpl implements VaultBackupTestRepository {
  String _key(String id, VaultBackupSource source) =>
      'vault_descriptor_test_v1.$id.${source.name}';

  @override
  Future<Result<Map<VaultBackupSource, DateTime>, BackupSettingsFailure>> load(
    String descriptorId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dates = <VaultBackupSource, DateTime>{};
      for (final source in VaultBackupSource.values) {
        final value = prefs.get(_key(descriptorId, source));
        if (value == null) continue;
        if (value is! int || value <= 0 || value > 8640000000000000) {
          return const Err(BackupSettingsStorageFailure());
        }
        dates[source] = DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      }
      return Ok(Map.unmodifiable(dates));
    } on Exception {
      return const Err(BackupSettingsStorageFailure());
    }
  }

  @override
  Future<Result<void, BackupSettingsFailure>> record(
    VaultBackupTest test,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setInt(
        _key(test.descriptorId, test.source),
        test.verifiedAt.millisecondsSinceEpoch,
      );
      return saved ? const Ok(null) : const Err(BackupSettingsStorageFailure());
    } on Exception {
      return const Err(BackupSettingsStorageFailure());
    }
  }
}
