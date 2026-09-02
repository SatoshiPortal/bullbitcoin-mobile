abstract final class WalletMetadataBackupLimits {
  static const int maxDecryptedSnapshotBytes = 1024 * 1024 - 64;
  static const int maxLogicalRecords = 5000;
  static const int maxStringBytes = 64 * 1024;

  const WalletMetadataBackupLimits._();
}
