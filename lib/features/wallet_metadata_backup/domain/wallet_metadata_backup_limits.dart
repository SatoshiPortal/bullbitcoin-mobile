abstract final class WalletMetadataBackupLimits {
  static const int maxCiphertextBytes = 2 * 1024 * 1024;
  static const int maxDecryptedSnapshotBytes = maxCiphertextBytes - 64;
  static const int maxLogicalRecords = 5000;
  static const int maxRecordCanonicalBytes = 64 * 1024;
  static const int maxJsonDepth = 32;
  static const int maxJsonCollectionLength = maxLogicalRecords;
  static const int maxStringBytes = maxRecordCanonicalBytes;
  static const int maxSignedInt64 = 0x7fffffffffffffff;
  static const int minSignedInt64 = -0x8000000000000000;

  const WalletMetadataBackupLimits._();
}
