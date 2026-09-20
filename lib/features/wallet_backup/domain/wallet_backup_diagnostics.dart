import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/vault_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bull_logger/bull_logger.dart';

enum WalletBackupOperation {
  mutation,
  publish,
  recover,
  recoverFile,
  recoverVaults,
  delete,
  export,
}

/// Only operation names and typed failure classes cross the diagnostic boundary.
Result<T, WalletBackupFailure> logWalletBackupCompletion<T>(
  WalletBackupOperation operation,
  Result<T, WalletBackupFailure> result,
) {
  final failure = switch (result) {
    Err(:final failure) => failure,
    Ok(value: WalletBackupRecovery(complete: false, :final failure)) ||
    Ok(
      value: VaultBackupRecovery(complete: false, :final failure),
    ) => failure ?? const WalletBackupIncompleteFailure(),
    Ok() => null,
  };
  final message =
      'wallet_backup operation=${operation.name} '
      'failure_class=${failure?.runtimeType ?? 'none'}';
  if (failure == null) {
    log.info(message);
  } else {
    log.warning(message);
  }
  return result;
}

String walletBackupSizeBucket(int bytes) => switch (bytes) {
  <= 1024 => '0-1KiB',
  <= 8192 => '1-8KiB',
  <= 65536 => '8-64KiB',
  <= 524288 => '64-512KiB',
  _ => 'over512KiB',
};
