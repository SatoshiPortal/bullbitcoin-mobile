import 'dart:async';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Admission and native work share an absolute run deadline. A fresh coordinator still uses the shell's common durable database and capacity.
final class AdmitWalletSyncUsecase {
  final WalletSourceOperationCoordinator Function(Duration acquisitionTimeout)
  _coordinatorForTimeout;
  final DateTime Function() _now;

  AdmitWalletSyncUsecase({
    required this._coordinatorForTimeout,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  Future<Result<T, WalletTransactionSyncFailure>> execute<T>({
    required WalletSourceKey key,
    required DateTime deadline,
    required Future<Result<T, WalletTransactionSyncFailure>> Function(
      WalletSourceSession session,
    )
    operation,
  }) async {
    final remaining = deadline.difference(_now());
    if (remaining <= Duration.zero) {
      return const Err(WalletSyncDeferredFailure());
    }
    var admitted = false;
    try {
      return await _coordinatorForTimeout(remaining).runExclusive(
        key,
        (session) async {
          admitted = true;
          // Initialization itself may have spent the remaining time.
          if (!_now().isBefore(deadline)) {
            return Err<T, WalletTransactionSyncFailure>(
              const WalletSyncDeferredFailure(),
            );
          }
          return operation(session);
        },
        kind: WalletOperationKind.synchronize,
        priority: WalletOperationPriority.background,
        timeout: null,
      );
    } on TimeoutException {
      if (!admitted) return const Err(WalletSyncDeferredFailure());
      rethrow;
    }
  }
}
