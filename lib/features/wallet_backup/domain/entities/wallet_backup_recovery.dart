import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

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
  comparisonStale,
}

final class WalletBackupRecoveryResult {
  final WalletBackupRecoveryStatus status;
  final int restoredCount;
  final int failedCount;

  const WalletBackupRecoveryResult({
    required this.status,
    this.restoredCount = 0,
    this.failedCount = 0,
  });

  factory WalletBackupRecoveryResult.fromFailure(WalletBackupFailure failure) =>
      WalletBackupRecoveryResult(status: statusForFailure(failure));

  static WalletBackupRecoveryStatus statusForFailure(
    WalletBackupFailure failure,
  ) => switch (failure) {
    WalletBackupRemoteUnavailableFailure() ||
    WalletBackupRateLimitedFailure() => WalletBackupRecoveryStatus.unavailable,
    WalletBackupUnsupportedEnvelopeVersionFailure() =>
      WalletBackupRecoveryStatus.newerVersion,
    WalletBackupHeadConflictFailure() => WalletBackupRecoveryStatus.conflict,
    WalletBackupInvalidEnvelopeFailure() ||
    WalletBackupTooLargeFailure() ||
    WalletBackupParentFingerprintMismatchFailure() ||
    WalletBackupEncryptionFailure() ||
    WalletBackupInvalidRemoteFailure() ||
    WalletBackupManifestFailure() ||
    WalletBackupDefinitionsFailure() => WalletBackupRecoveryStatus.invalid,
    _ => WalletBackupRecoveryStatus.localFailure,
  };
}

final class WalletBackupManifestRestoreResult {
  final int restoredCount;
  final int failedCount;

  const WalletBackupManifestRestoreResult({
    required this.restoredCount,
    required this.failedCount,
  });
}
