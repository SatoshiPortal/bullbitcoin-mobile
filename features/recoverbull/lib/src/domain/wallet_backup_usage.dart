/// The historical backup facts for one wallet usage. Keep the raw timestamps
/// and both acknowledgements even when several uses share a single secret.
typedef WalletBackupUsage = ({
  String walletId,
  String? secretFingerprint,
  bool encryptedVaultTested,
  bool physicalBackupTested,
  int? latestEncryptedBackup,
  int? latestPhysicalBackup,
});

typedef SecretBackupProjection = ({
  bool encryptedVaultTested,
  bool physicalBackupTested,
  int? latestEncryptedBackup,
  int? latestPhysicalBackup,
});
