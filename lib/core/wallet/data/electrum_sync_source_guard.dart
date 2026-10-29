import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Guards only legacy history synchronization/discovery after source admission. Other remote operations need their own wallet-attributed privacy guard.
/// [allowCbfRouting] belongs only on a shell that rereads saved policy and dispatches CBF under this same session.
final class ElectrumSyncSourceGuard
    implements WalletSourceOperationCoordinator {
  final WalletSourceOperationCoordinator _coordinator;
  final WalletMetadataDatasource _metadata;
  final bool allowCbfRouting;

  ElectrumSyncSourceGuard({
    required this._coordinator,
    required this._metadata,
    this.allowCbfRouting = false,
  });

  @override
  Future<T> runExclusive<T>(
    WalletSourceKey key,
    Future<T> Function(WalletSourceSession session) operation, {
    Duration? timeout = const Duration(seconds: 30),
    DateTime? admissionDeadline,
    bool allowRetired = false,
    WalletOperationKind kind = WalletOperationKind.refresh,
    WalletOperationPriority priority = WalletOperationPriority.foreground,
  }) => _coordinator.runExclusive(
    key,
    (session) async {
      if (!allowCbfRouting &&
          key.chain == 'bitcoin' &&
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
    admissionDeadline: admissionDeadline,
    allowRetired: allowRetired,
    kind: kind,
    priority: priority,
  );
}

/// A legacy history request reached a coordinator without CBF routing. This does not describe the native transport's availability and never authorizes an Electrum fallback.
final class BitcoinSyncSourceUnavailableException implements Exception {
  const BitcoinSyncSourceUnavailableException();

  @override
  String toString() => 'Selected Bitcoin sync source is unavailable';
}
