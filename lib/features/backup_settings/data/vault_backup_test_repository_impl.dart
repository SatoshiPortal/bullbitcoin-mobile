import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/vault_backup_test_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One independently written preference per descriptor/source, not a shared
/// read-modify-write JSON object that can lose another source's result.
///
/// Each value is the retrieval time and the endpoint it came from, in one
/// write: a date and the place it belongs to can never disagree.
final class VaultBackupTestRepositoryImpl implements VaultBackupTestRepository {
  static const _maxMillis = 8640000000000000;

  String _key(String id, VaultBackupSource source) =>
      'vault_descriptor_test_v1.$id.${source.name}';

  @override
  Future<Result<Map<VaultBackupSource, DateTime>, BackupSettingsFailure>> load(
    String descriptorId, {
    required String endpoint,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dates = <VaultBackupSource, DateTime>{};
      for (final source in VaultBackupSource.values) {
        final value = prefs.get(_key(descriptorId, source));
        if (value == null) continue;
        if (value is! String) return const Err(BackupSettingsStorageFailure());
        final separator = value.indexOf('|');
        final millis = int.tryParse(
          separator < 0 ? value : value.substring(0, separator),
        );
        if (separator < 0 ||
            millis == null ||
            millis <= 0 ||
            millis > _maxMillis) {
          return const Err(BackupSettingsStorageFailure());
        }
        final recorded = value.substring(separator + 1);
        if (recorded != VaultBackupTest.anyEndpoint && recorded != endpoint) {
          continue;
        }
        dates[source] = DateTime.fromMillisecondsSinceEpoch(
          millis,
          isUtc: true,
        );
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
      final saved = await prefs.setString(
        _key(test.descriptorId, test.source),
        '${test.verifiedAt.millisecondsSinceEpoch}|${test.endpoint}',
      );
      return saved ? const Ok(null) : const Err(BackupSettingsStorageFailure());
    } on Exception {
      return const Err(BackupSettingsStorageFailure());
    }
  }
}
