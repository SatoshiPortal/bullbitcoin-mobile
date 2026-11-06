export 'package:bb_mobile/features/wallet/domain/seed_reference_port.dart'
    show SeedReferences;
import 'package:transaction_sync/transaction_sync.dart';
import 'package:primitives/primitives.dart' show Result, Err;
import '../domain/wallet_discovery_failure.dart';
export 'package:primitives/primitives.dart' show Result;
export '../domain/wallet_discovery_failure.dart';

export 'package:transaction_sync/transaction_sync.dart'
    show WalletRevisionState, WalletRevision, WalletKey, WalletLifecycle;
export '../wallet_sync_locator.dart' show SyncLocator, initializeWalletRuntime;
export '../background_setup.dart'
    show setupBackgroundWalletTask, paymentNotificationChannelId;

/// Wallet-owned invalidations. A revision is not a successful network sync.
final class WalletFacade {
  final Stream<WalletRevisionState> _revisions;
  final Future<Result<void, WalletDiscoveryFailure>> Function(String)?
  _discoverWallet;
  final Stream<bool> _syncPassActivity;
  final bool Function()? _isSyncPassActive;
  const WalletFacade(
    this._revisions, {
    this._discoverWallet,
    this._syncPassActivity = const Stream.empty(),
    this._isSyncPassActive,
  });

  bool get isSyncPassActive => _isSyncPassActive?.call() ?? false;
  Stream<bool> watchSyncPassActivity() => _syncPassActivity;

  Future<Result<void, WalletDiscoveryFailure>> discoverWallet(
    String walletId,
  ) async {
    final discover = _discoverWallet;
    if (discover == null) return const Err(WalletDiscoveryUnavailableFailure());
    return discover(walletId);
  }

  Stream<WalletRevisionState> watchRevisions({String? walletId}) =>
      _revisions.where(
        (revision) => walletId == null || revision.stamp.key.id == walletId,
      );
}
