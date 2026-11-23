/// The historical backup facts for one wallet usage. Keep the raw timestamps
/// and both acknowledgements even when several uses share a single secret.
/// Both `latest*Backup` fields are Unix epoch milliseconds, as stored by
/// `wallet_metadatas` v16. A null timestamp means no backup time was recorded.
typedef WalletBackupUsage = ({
  String walletId,
  String? secretFingerprint,
  bool encryptedVaultTested,
  bool physicalBackupTested,
  int? latestEncryptedBackup,
  int? latestPhysicalBackup,
});

/// Latest known timestamps are also in Unix epoch milliseconds.
typedef SecretBackupProjection = ({
  bool encryptedVaultTested,
  bool physicalBackupTested,
  int? latestEncryptedBackup,
  int? latestPhysicalBackup,
});
