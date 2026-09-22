import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_diagnostics.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Serializes this feature's publication, recovery and deletion mutations.
final class WalletBackupOperationQueue {
  static const _deadline = Duration(minutes: 1);
  Future<void> _tail = Future.value();

  @useResult
  Future<Result<T, WalletBackupFailure>> run<T>(
    Future<Result<T, WalletBackupFailure>> Function() operation, {
    WalletBackupOperation name = WalletBackupOperation.mutation,
  }) {
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    var expired = false;
    Future<Result<T, WalletBackupFailure>> invoke() async {
      await previous;
      try {
        if (expired) return const Err(WalletBackupTimeoutFailure());
        return await operation();
      } finally {
        finished.complete();
      }
    }

    // A timeout releases the caller, not an in-flight mutation. Later mutations still wait for it; a request that expires while waiting never runs.
    return invoke()
        .timeout(
          _deadline,
          onTimeout: () {
            expired = true;
            log.warning(
              'wallet_backup queue operation=${name.name} exceeded deadline',
            );
            return const Err(WalletBackupTimeoutFailure());
          },
        )
        .then((result) => logWalletBackupCompletion(name, result));
  }
}
