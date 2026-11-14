import 'package:background_tasks/background_tasks.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'wallet_payment_observer.dart';

final class BackgroundWalletSyncImpl implements BackgroundWalletSync {
  final WalletCatalogPort _catalog;
  final ElectrumSync _sync;
  final WalletPaymentObserver? _observer;

  const BackgroundWalletSyncImpl(this._catalog, this._sync, this._observer);

  @override
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> synchronize(
    WalletKey key, {
    required bool allowInitialScan,
    required bool discover,
  }) async {
    final descriptor = await _catalog.find(key);
    if (descriptor case Err(:final failure)) return Err(_failure(failure));
    final result = await _sync.execute(
      (descriptor as Ok<PublicWalletDescriptor, TransactionSyncFailure>).value,
      discover: discover,
      headless: true,
      reason: SyncReason.background,
      allowInitialScan: allowInitialScan,
      collectIncoming: _observer != null,
      onCompletion: _observer?.recordCompletion,
    );
    return switch (result) {
      Ok(
        value: SyncCompletion(
          revision: final WalletRevision revision,
          :final incomingTxids,
        ),
      ) =>
        Ok(
          BackgroundSyncOutcome(
            revision: revision,
            incomingTxids: incomingTxids,
            completedAt: DateTime.now(),
          ),
        ),
      Ok() => const Err(
        BackgroundSyncUnavailableFailure(
          BackgroundSyncUnavailableReason.storage,
        ),
      ),
      Err(:final failure) => Err(_failure(failure)),
    };
  }

  BackgroundSyncFailure _failure(
    TransactionSyncFailure failure,
  ) => switch (failure) {
    TransactionSyncInvalidAddressFailure() =>
      const BackgroundSyncUnavailableFailure(
        BackgroundSyncUnavailableReason.address,
      ),
    TransactionSyncBusyFailure() => const BackgroundSyncBusyFailure(),
    TransactionSyncUnsupportedNetworkFailure() =>
      const BackgroundSyncUnsupportedNetworkFailure(),
    TransactionSyncUnauthorizedNetworkFailure() =>
      const BackgroundSyncUnauthorizedNetworkFailure(),
    TransactionSyncInitialScanRequiredFailure() =>
      const BackgroundSyncInitialScanRequiredFailure(),
    TransactionSyncNeedsRepairFailure(
      revision: final WalletRevision revision,
    ) =>
      BackgroundSyncNeedsRepairFailure(revision),
    TransactionSyncConnectionFailure() =>
      const BackgroundSyncConnectionFailure(),
    TransactionSyncStorageFailure() => const BackgroundSyncUnavailableFailure(
      BackgroundSyncUnavailableReason.storage,
    ),
    TransactionSyncInvalidCatalogFailure() =>
      const BackgroundSyncUnavailableFailure(
        BackgroundSyncUnavailableReason.catalog,
      ),
    TransactionSyncNotFoundFailure() => const BackgroundSyncUnavailableFailure(
      BackgroundSyncUnavailableReason.missing,
    ),
    TransactionSyncNeedsRepairFailure() =>
      const BackgroundSyncUnavailableFailure(
        BackgroundSyncUnavailableReason.repair,
      ),
    TransactionSyncRestartRequiredFailure() =>
      const BackgroundSyncUnavailableFailure(
        BackgroundSyncUnavailableReason.restart,
      ),
  };
}
