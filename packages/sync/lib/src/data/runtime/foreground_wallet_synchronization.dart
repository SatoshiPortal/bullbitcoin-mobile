import 'package:primitives/primitives.dart';

import '../../domain/ports/wallet_catalog_port.dart';
import '../../domain/public_wallet_descriptor.dart';
import '../../domain/sync_completion.dart';
import '../../domain/sync_failure.dart';
import '../../domain/sync_reason.dart';
import '../../domain/sync_transaction_target.dart';
import '../../domain/wallet_key.dart';
import '../write/sync/electrum_sync.dart';
import 'wallet_native_runtime.dart';

/// Foreground synchronization and repair under the native writer's lifecycle.
final class ForegroundWalletSynchronization {
  final ElectrumSync _sync;
  final WalletNativeRuntime? _native;

  const ForegroundWalletSynchronization(this._sync, {this._native});

  Future<Result<void, SyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    bool discover = false,
    bool allowInitialScan = true,
    SyncReason reason = SyncReason.auto,
  }) async => (await _synchronize(
    descriptor,
    discover: discover,
    allowInitialScan: allowInitialScan,
    reason: reason,
  )).map((_) {});

  /// One targeted pass over [targets]: the server is asked only about the
  /// wallet scripts those transactions touch, and the completion reports which
  /// of them the pass proved visible.
  ///
  /// The pass never initializes or scans a wallet, so a wallet without an
  /// initial scan fails with `SyncInitialScanRequiredFailure` instead of
  /// scanning. The native refresh that follows republishes the wallet values
  /// the pass committed, exactly like an ordinary sync.
  Future<Result<SyncCompletion, SyncFailure>> executeTargeted(
    PublicWalletDescriptor descriptor, {
    required List<SyncTransactionTarget> targets,
    SyncReason reason = SyncReason.auto,
  }) => _synchronize(
    descriptor,
    allowInitialScan: false,
    reason: reason,
    targets: targets,
  );

  Future<Result<SyncCompletion, SyncFailure>> _synchronize(
    PublicWalletDescriptor descriptor, {
    bool discover = false,
    bool allowInitialScan = true,
    SyncReason reason = SyncReason.auto,
    List<SyncTransactionTarget> targets = const <SyncTransactionTarget>[],
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
      targets: targets,
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
        targets: targets,
      );
    }
    if (native != null) {
      if (await native.refresh(descriptor.key) case Err(:final failure)) {
        return Err(failure);
      }
    }
    return result;
  }

  /// Synchronizes the wallet that [catalog] resolves for [key].
  Future<Result<void, SyncFailure>> executeKey(
    WalletKey key,
    WalletCatalogPort catalog, {
    SyncReason reason = SyncReason.auto,
  }) async => switch (await catalog.find(key)) {
    Ok(:final value) => await execute(value, reason: reason),
    Err(:final failure) => Err(failure),
  };
}
