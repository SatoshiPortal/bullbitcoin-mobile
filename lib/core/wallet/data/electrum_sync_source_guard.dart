import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Rejects legacy Electrum history operations after admission, under the same
/// lock used to change the persisted preference. Queued jobs must not use a
/// stale Electrum selection. Local reads and deletion remain available.
final class ElectrumSyncSourceGuard
    implements WalletSourceOperationCoordinator {
  final WalletSourceOperationCoordinator _coordinator;
  final WalletMetadataDatasource _metadata;

  ElectrumSyncSourceGuard({
    required this._coordinator,
    required this._metadata,
  });

  @override
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession session) operation, {
    Duration? timeout = const Duration(seconds: 30),
    bool allowRetired = false,
    WalletOperationKind kind = WalletOperationKind.refresh,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) => _coordinator.runExclusive(
    key,
    (session) async {
      if (key.chain == 'bitcoin' &&
          (kind == WalletOperationKind.synchronize ||
              kind == WalletOperationKind.discover)) {
        final metadata = await _metadata.fetch(key.walletId);
        if (metadata?.bitcoinSyncSource ==
            BitcoinSyncSource.compactBlockFilters) {
          throw const BitcoinSyncSourceUnavailableException();
        }
      }
      return operation(session);
    },
    timeout: timeout,
    allowRetired: allowRetired,
    kind: kind,
    priority: priority,
  );
}

/// The CBF transport is deliberately unavailable until its bindings are wired.
/// Never route this outcome to an Electrum fallback.
final class BitcoinSyncSourceUnavailableException implements Exception {
  const BitcoinSyncSourceUnavailableException();

  @override
  String toString() => 'Selected Bitcoin sync source is unavailable';
}
