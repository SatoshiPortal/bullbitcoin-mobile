import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

/// Temporary bridge for legacy repository consumers until capability extraction. Mapping belongs to the wallet owner, never the native writer or core.
final class ForegroundWalletSync {
  final ElectrumSync _sync;
  final WalletNativeRuntime? _native;

  ForegroundWalletSync(this._sync, {this._native});

  Stream<String> get started => _sync.started.map((key) => key.id);
  Stream<String> get finished => _sync.finished.map((event) => event.key.id);
  Stream<ElectrumSyncResult> get results =>
      ElectrumSyncResult.watch(_sync.finished);

  bool isSyncing({String? walletId}) => _sync.isSyncing(walletId: walletId);

  Future<void> synchronize(
    WalletMetadataModel metadata, {
    bool discover = false,
    bool allowInitialScan = true,
    SyncReason reason = SyncReason.auto,
  }) async {
    final descriptor = WalletCatalogPortImpl.descriptorFromMetadata(metadata);
    switch (descriptor) {
      case Err():
        throw const WalletStorageFailure('Invalid sync descriptor');
      case Ok(:final value):
        await _native?.initialize();
        var result = await _sync.execute(
          value,
          discover: discover,
          allowInitialScan: allowInitialScan,
          reason: reason,
        );
        final native = _native;
        if (result case Err(failure: SyncNeedsRepairFailure())
            when native != null) {
          WalletCatalogPortImpl.value(await native.repair(value.key));
          result = await _sync.execute(
            value,
            discover: discover,
            allowInitialScan: allowInitialScan,
            reason: reason,
          );
        }
        if (native != null) {
          WalletCatalogPortImpl.value(await native.refresh(value.key));
        }
        if (result case Err(:final failure)) {
          // Legacy void/throw boundary only. The package always returns Result. Repair is owned by the writer and never by a reader.
          throw WalletSnapshotException(failure);
        }
    }
  }
}
