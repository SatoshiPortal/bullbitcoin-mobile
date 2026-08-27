import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class WalletDefinitionsRecoveryResult {
  final int restoredCount;
  final int failedCount;
  final List<String> createdWalletRefs;

  WalletDefinitionsRecoveryResult({
    required this.restoredCount,
    required this.failedCount,
    required List<String> createdWalletRefs,
  }) : createdWalletRefs = List.unmodifiable(createdWalletRefs);
}

abstract interface class WalletDefinitionsBackup {
  Stream<void> get changes;

  @useResult
  Future<Result<String?, WalletBackupFailure>> compose({
    required String? remotePayload,
  });

  @useResult
  Future<Result<WalletDefinitionsRecoveryResult, WalletBackupFailure>> recover({
    required String payload,
    DateTime? deadline,
  });
}
