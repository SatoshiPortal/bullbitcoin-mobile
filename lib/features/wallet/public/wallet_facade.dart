import '../domain/wallet_spend_failure.dart';
export '../domain/wallet_spend_failure.dart';
export 'package:bb_mobile/features/wallet/domain/seed_reference_port.dart'
    show SeedReferences;
export '../domain/wallet.dart' show Network;
export '../domain/network_x.dart' show NetworkX;
import 'package:sync/sync.dart';
import 'package:primitives/primitives.dart' show Result, Err, BitcoinNetwork;
import '../domain/wallet_discovery_failure.dart';
export 'package:primitives/primitives.dart' show Result;
export '../domain/wallet_discovery_failure.dart';

export 'package:sync/sync.dart'
    show
        BitcoinBroadcastReceipt,
        BitcoinSpendStatus,
        WalletRevisionState,
        WalletRevision,
        WalletKey,
        WalletLifecycle;
export '../wallet_sync_locator.dart' show SyncLocator, initializeWalletRuntime;
export '../background_setup.dart'
    show setupBackgroundWalletTask, paymentNotificationChannelId;

/// Wallet-owned invalidations. A revision is not a successful network sync.
final class WalletFacade {
  final Future<BitcoinSpendStatus> Function(String, {String? replacing})?
  _spendStatus;
  final Future<Result<BitcoinBroadcastReceipt, WalletSpendFailure>> Function(
    String,
    BitcoinNetwork,
    Future<String> Function(),
  )?
  _broadcastBitcoin;
  final Future<bool> Function(String, String)? _protectObservedSpend;
  final Stream<WalletRevisionState> _revisions;
  final Future<Result<void, WalletDiscoveryFailure>> Function(String)?
  _discoverWallet;
  final Future<void> Function(String, {required bool Function() isActive})?
  _pollWallet;
  final Stream<void> _syncFinished;
  final Stream<bool> _syncPassActivity;
  final bool Function()? _isSyncPassActive;
  const WalletFacade(
    this._revisions, {
    this._spendStatus,
    this._broadcastBitcoin,
    this._protectObservedSpend,
    this._discoverWallet,
    this._pollWallet,
    this._syncFinished = const Stream.empty(),
    this._syncPassActivity = const Stream.empty(),
    this._isSyncPassActive,
  });

  Future<BitcoinSpendStatus> spendStatus(
    String walletId, {
    String? replacing,
  }) async =>
      _spendStatus?.call(walletId, replacing: replacing) ??
      BitcoinSpendStatus.unavailable;

  Future<Result<BitcoinBroadcastReceipt, WalletSpendFailure>> broadcastBitcoin(
    String walletId,
    BitcoinNetwork network,
    Future<String> Function() broadcast,
  ) async =>
      _broadcastBitcoin?.call(walletId, network, broadcast) ??
      const Err(WalletSpendBlockedFailure(BitcoinSpendStatus.unavailable));

  Future<bool> protectObservedSpend(String walletId, String txid) async =>
      _protectObservedSpend?.call(walletId, txid) ?? false;

  /// Raw completion, including failures without a revision; never hydrates a wallet.
  Stream<void> watchSyncFinished() => _syncFinished;

  bool get isSyncPassActive => _isSyncPassActive?.call() ?? false;
  Stream<bool> watchSyncPassActivity() => _syncPassActivity;

  Future<Result<void, WalletDiscoveryFailure>> discoverWallet(
    String walletId,
  ) async {
    final discover = _discoverWallet;
    if (discover == null) return const Err(WalletDiscoveryUnavailableFailure());
    return discover(walletId);
  }

  /// Settles when the requested or already covering wallet pass ends.
  /// Best-effort routine sync; a false predicate cancels pending admission.
  Future<void> pollWallet(
    String walletId, {
    required bool Function() isActive,
  }) async => _pollWallet?.call(walletId, isActive: isActive);

  Stream<WalletRevisionState> watchRevisions({String? walletId}) =>
      _revisions.where(
        (revision) => walletId == null || revision.stamp.key.id == walletId,
      );
}
