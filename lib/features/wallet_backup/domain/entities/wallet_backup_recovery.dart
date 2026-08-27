enum WalletBackupRecoveryStatus {
  noBackup,
  restored,
  partiallyRestored,
  invalid,
  unavailable,
  newerVersion,
  conflict,
  localFailure,
  timedOut,
}

final class WalletBackupRecoveryResult {
  final WalletBackupRecoveryStatus status;
  final int restoredCount;
  final int failedCount;
  final List<String> createdWalletIds;

  const WalletBackupRecoveryResult({
    required this.status,
    this.restoredCount = 0,
    this.failedCount = 0,
    this.createdWalletIds = const [],
  });
}

final class WalletBackupManifestRestoreResult {
  final int restoredCount;
  final int failedCount;
  final List<String> createdWalletIds;

  const WalletBackupManifestRestoreResult({
    required this.restoredCount,
    required this.failedCount,
    required this.createdWalletIds,
  });
}
