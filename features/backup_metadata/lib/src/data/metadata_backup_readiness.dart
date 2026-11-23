import '../domain/ports/backup_readiness_port.dart';

/// Defers a headless run until the host admits storage and the foreground
/// has already migrated the app database. Neither check opens an owner store.
final class MetadataBackupReadiness implements BackupReadinessPort {
  final bool Function() _hasStorageAdmission;
  final Future<bool> Function() _isAtCurrentSchema;

  const MetadataBackupReadiness({
    required bool Function() hasStorageAdmission,
    required Future<bool> Function() isAtCurrentSchema,
  }) : _hasStorageAdmission = hasStorageAdmission,
       _isAtCurrentSchema = isAtCurrentSchema;

  @override
  Future<bool> databaseReady() async {
    if (!_hasStorageAdmission()) return false;
    try {
      return await _isAtCurrentSchema() && _hasStorageAdmission();
    } on Exception {
      return false;
    }
  }
}
