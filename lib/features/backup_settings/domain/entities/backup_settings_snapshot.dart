enum WalletMetadataBackupNowStatus { saved, unchanged, notReady }

final class WalletMetadataBackupSettingsSnapshot {
  final bool enabled;
  final bool dirty;
  final bool blocked;
  final bool hasRemoteBackup;
  final DateTime? lastVerifiedAt;

  const WalletMetadataBackupSettingsSnapshot({
    required this.enabled,
    required this.dirty,
    required this.blocked,
    this.hasRemoteBackup = false,
    this.lastVerifiedAt,
  });
}

final class BackupSettingsSnapshot {
  final bool isDefaultPhysicalBackupTested;
  final DateTime? lastPhysicalBackup;
  final bool isDefaultEncryptedBackupTested;
  final DateTime? lastEncryptedBackup;
  final WalletMetadataBackupSettingsSnapshot walletMetadata;

  const BackupSettingsSnapshot({
    required this.isDefaultPhysicalBackupTested,
    required this.lastPhysicalBackup,
    required this.isDefaultEncryptedBackupTested,
    required this.lastEncryptedBackup,
    required this.walletMetadata,
  });
}

final class WalletMetadataBackupNowResult {
  final WalletMetadataBackupNowStatus status;
  final WalletMetadataBackupSettingsSnapshot settings;

  const WalletMetadataBackupNowResult({
    required this.status,
    required this.settings,
  });
}
