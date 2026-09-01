import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
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

  /// The definitions to publish, read from local state alone. An empty list
  /// leaves the section out of the published snapshot, which is how the last
  /// external wallet is deleted (spec F1, F2).
  @useResult
  Future<Result<List<WalletDefinition>, WalletBackupFailure>> read();

  @useResult
  Future<Result<WalletDefinitionsRecoveryResult, WalletBackupFailure>> recover({
    required List<WalletDefinition> definitions,
    DateTime? deadline,
  });
}
