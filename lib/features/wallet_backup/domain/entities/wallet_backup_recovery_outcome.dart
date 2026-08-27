import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';

final class WalletBackupRecoveryOutcome {
  final WalletBackupRecoveryStatus status;
  final int completedAt;
  final int restoredCount;
  final int failedCount;

  const WalletBackupRecoveryOutcome({
    required this.status,
    required this.completedAt,
    required this.restoredCount,
    required this.failedCount,
  });

  bool get isIncomplete =>
      status == WalletBackupRecoveryStatus.partiallyRestored ||
      status == WalletBackupRecoveryStatus.timedOut;
}
