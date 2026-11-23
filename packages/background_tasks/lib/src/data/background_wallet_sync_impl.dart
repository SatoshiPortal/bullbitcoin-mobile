import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import '../domain/ports/background_wallet_sync_port.dart';

final class BackgroundWalletSyncImpl implements BackgroundWalletSyncPort {
  final WalletCatalogPort _catalog;
  final ElectrumSync _sync;

  /// Collects the incoming history only when it can be announced.
  final bool _collectIncoming;

  const BackgroundWalletSyncImpl(
    this._catalog,
    this._sync, {
    required this._collectIncoming,
  });

  @override
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> synchronize(
    WalletKey key, {
    required bool allowInitialScan,
    required bool discover,
  }) async {
    final descriptor = await _catalog.find(key);
    if (descriptor case Err(:final failure)) return Err(_failure(failure));
    final result = await _sync.execute(
      (descriptor as Ok<PublicWalletDescriptor, SyncFailure>).value,
      discover: discover,
      headless: true,
      reason: SyncReason.background,
      allowInitialScan: allowInitialScan,
      collectIncoming: _collectIncoming,
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

  BackgroundSyncFailure _failure(SyncFailure failure) => switch (failure) {
    SyncInvalidAddressFailure() => const BackgroundSyncUnavailableFailure(
      BackgroundSyncUnavailableReason.address,
    ),
    SyncBusyFailure() => const BackgroundSyncBusyFailure(),
    SyncUnsupportedNetworkFailure() =>
      const BackgroundSyncUnsupportedNetworkFailure(),
    SyncUnauthorizedNetworkFailure() =>
      const BackgroundSyncUnauthorizedNetworkFailure(),
    SyncInitialScanRequiredFailure() =>
      const BackgroundSyncInitialScanRequiredFailure(),
    SyncNeedsRepairFailure(revision: final WalletRevision revision) =>
      BackgroundSyncNeedsRepairFailure(revision),
    SyncConnectionFailure() => const BackgroundSyncConnectionFailure(),
    SyncStorageFailure() => const BackgroundSyncUnavailableFailure(
      BackgroundSyncUnavailableReason.storage,
    ),
    SyncInvalidCatalogFailure() => const BackgroundSyncUnavailableFailure(
      BackgroundSyncUnavailableReason.catalog,
    ),
    SyncNotFoundFailure() => const BackgroundSyncUnavailableFailure(
      BackgroundSyncUnavailableReason.missing,
    ),
    SyncNeedsRepairFailure() => const BackgroundSyncUnavailableFailure(
      BackgroundSyncUnavailableReason.repair,
    ),
    // A refresh decodes, builds and broadcasts nothing: chain and spend
    // failures are unreachable.
    SyncRestartRequiredFailure() ||
    SyncClosedFailure() ||
    SyncChainFailure() ||
    SyncSpendFailure() => const BackgroundSyncUnavailableFailure(
      BackgroundSyncUnavailableReason.restart,
    ),
  };
}
