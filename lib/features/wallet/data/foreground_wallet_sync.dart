import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
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
    final descriptor = WalletSyncBinding.descriptorFromMetadata(metadata);
    switch (descriptor) {
      case Err():
        throw const WalletStorageFailure('Invalid sync descriptor');
      case Ok(:final value):
        WalletSyncBinding.value(
          await synchronizeDescriptor(
            value,
            discover: discover,
            allowInitialScan: allowInitialScan,
            reason: reason,
          ),
        );
    }
  }

  Future<Result<void, SyncFailure>> synchronizeKey(
    WalletKey key,
    WalletCatalogPort catalog,
  ) async => switch (await catalog.find(key)) {
    Ok(:final value) => await synchronizeDescriptor(value),
    Err(:final failure) => Err(failure),
  };

  Future<Result<void, SyncFailure>> synchronizeDescriptor(
    PublicWalletDescriptor descriptor, {
    bool discover = false,
    bool allowInitialScan = true,
    SyncReason reason = SyncReason.auto,
  }) async {
    final native = _native;
    if (native != null) {
      if (await native.initialize() case Err(:final failure)) {
        return Err(failure);
      }
    }
    var result = await _sync.execute(
      descriptor,
      discover: discover,
      allowInitialScan: allowInitialScan,
      reason: reason,
    );
    if (result case Err(failure: SyncNeedsRepairFailure())
        when native != null) {
      if (await native.repair(descriptor.key) case Err(:final failure)) {
        return Err(failure);
      }
      result = await _sync.execute(
        descriptor,
        discover: discover,
        allowInitialScan: allowInitialScan,
        reason: reason,
      );
    }
    if (native != null) {
      if (await native.refresh(descriptor.key) case Err(:final failure)) {
        return Err(failure);
      }
    }
    return result.map((_) {});
  }
}
