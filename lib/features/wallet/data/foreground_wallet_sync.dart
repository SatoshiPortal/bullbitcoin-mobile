import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Temporary bridge for legacy repository consumers until capability extraction. Mapping belongs to the wallet owner, never the native writer or core.
final class ForegroundWalletSync {
  final ElectrumSync _sync;

  ForegroundWalletSync(this._sync);

  Stream<String> get started => _sync.started.map((key) => key.id);
  Stream<String> get finished => _sync.finished.map((event) => event.key.id);
  Stream<ElectrumSyncResult> get results => _sync.finished.map(
    (event) => ElectrumSyncResult(
      isLiquid: event.key.network is LiquidNetwork,
      success: event.result is Ok<SyncCompletion, TransactionSyncFailure>,
    ),
  );

  bool isSyncing({String? walletId}) => _sync.isSyncing(walletId: walletId);

  Future<void> synchronize(
    WalletMetadataModel metadata, {
    bool discover = false,
  }) async {
    final descriptor = WalletCatalogPortImpl.descriptorFromMetadata(metadata);
    switch (descriptor) {
      case Err():
        throw const WalletStorageFailure('Invalid sync descriptor');
      case Ok(:final value):
        final result = await _sync.execute(value, discover: discover);
        // Busy is a skipped foreground pass. The failed completion remains
        // visible through results, without escalating contention as an error.
        if (result case Err(failure: TransactionSyncBusyFailure())) return;
        if (result case Err(:final failure)) {
          // Legacy void/throw boundary only. The package always returns Result. The temporary status-conflict mapping preserves startup recovery until the writer repair cutover.
          throw switch (failure) {
            TransactionSyncNeedsRepairFailure() =>
              const WalletLwkStatusConflictFailure(
                'Native wallet needs repair',
              ),
            TransactionSyncConnectionFailure() => const WalletSyncFailure(
              'Electrum sync failed',
            ),
            _ => const WalletStorageFailure('Native wallet sync failed'),
          };
        }
    }
  }
}
