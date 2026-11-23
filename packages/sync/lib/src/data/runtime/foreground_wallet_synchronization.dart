import 'package:primitives/primitives.dart';

import '../../domain/public_wallet_descriptor.dart';
import '../../domain/sync_failure.dart';
import '../../domain/sync_reason.dart';
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
