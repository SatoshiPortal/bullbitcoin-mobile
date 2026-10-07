/// The last digest read from a Google Drive backup file, kept so discovery
/// can skip downloading files whose modification time did not change.
final class DriveBackupCacheEntry {
  /// SHA-256 (hex) of the Google account e-mail, never the address itself.
  final String accountHash;
  final String driveFileId;
  final List<int> backupDigest;
  final DateTime driveFileCreatedAt;
  final DateTime? driveFileModifiedAt;

  DriveBackupCacheEntry({
    required this.accountHash,
    required this.driveFileId,
    required List<int> backupDigest,
    required this.driveFileCreatedAt,
    this.driveFileModifiedAt,
  }) : backupDigest = List<int>.unmodifiable(backupDigest);
}
