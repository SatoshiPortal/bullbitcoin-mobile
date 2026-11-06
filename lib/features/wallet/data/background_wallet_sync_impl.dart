import 'package:background_tasks/background_tasks.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'wallet_payment_observer.dart';

final class BackgroundWalletSyncImpl implements BackgroundWalletSync {
  final WalletCatalogPort _catalog;
  final ElectrumSync _sync;
  final WalletPaymentObserver _observer;

  const BackgroundWalletSyncImpl(this._catalog, this._sync, this._observer);

  @override
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> synchronize(
    WalletKey key, {
    required bool allowInitialScan,
  }) async {
    final descriptor = await _catalog.find(key);
    if (descriptor case Err(:final failure)) return Err(_failure(failure));
    final result = await _sync.execute(
      (descriptor as Ok<PublicWalletDescriptor, TransactionSyncFailure>).value,
      headless: true,
      allowInitialScan: allowInitialScan,
      onCompletion: _observer.record,
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
      Ok() => const Err(BackgroundSyncConnectionFailure()),
      Err(:final failure) => Err(_failure(failure)),
    };
  }

  BackgroundSyncFailure _failure(TransactionSyncFailure failure) =>
      switch (failure) {
        TransactionSyncBusyFailure() => const BackgroundSyncBusyFailure(),
        TransactionSyncUnsupportedNetworkFailure() =>
          const BackgroundSyncUnsupportedNetworkFailure(),
        TransactionSyncInitialScanRequiredFailure() =>
          const BackgroundSyncInitialScanRequiredFailure(),
        TransactionSyncNeedsRepairFailure(
          revision: final WalletRevision revision,
        ) =>
          BackgroundSyncNeedsRepairFailure(revision),
        _ => const BackgroundSyncConnectionFailure(),
      };
}
