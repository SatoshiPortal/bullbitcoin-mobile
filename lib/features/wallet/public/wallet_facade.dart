import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
export 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';

export '../ui/widgets/wallet_detail_balance_card.dart'
    show WalletDetailBalanceCard;

export '../domain/wallet.dart' show Network;
export '../domain/network_x.dart' show NetworkX;

import 'package:sync/sync.dart';

import 'package:bb_mobile/features/send/public/send_setup.dart'
    show BroadcastSpend;

import 'package:primitives/primitives.dart' as primitives show Network;
import 'package:primitives/primitives.dart' show NetworkEnv, Result, Err;

import '../domain/wallet_discovery_failure.dart';

export 'package:primitives/primitives.dart' show NetworkEnv, Result;

export '../domain/wallet_discovery_failure.dart';

export 'package:sync/sync.dart'
    show
        BitcoinSpendStatus,
        SignedBitcoinTransaction,
        SignedPset,
        SignedPsbt,
        SignedTransaction,
        SpendOwner,
        SpendReceipt,
        SyncFailure,
        UnsignedSpend,
        WalletRevisionState,
        WalletRevision,
        WalletKey,
        WalletLifecycle;

export '../wallet_sync_locator.dart' show SyncLocator, initializeWalletRuntime;
export '../background_setup.dart'
    show
        setupBackgroundWalletTask,
        prepareBackgroundWalletStores,
        paymentNotificationChannelId;

/// Wallet-owned invalidations. A revision is not a successful network sync.
final class WalletFacade {
  final Future<Result<String, WalletFailure>> Function(
    String, {
    Set<String> excludedAddresses,
  })?
  _nextReceiveAddress;

  Future<Result<String, WalletFailure>> nextReceiveAddress(
    String walletId, {
    Set<String> excludedAddresses = const {},
  }) async =>
      _nextReceiveAddress?.call(
        walletId,
        excludedAddresses: excludedAddresses,
      ) ??
      const Err(WalletStorageFailure('receive capability unavailable'));

  final Future<BitcoinSpendStatus> Function(String, {String? replacing})?
  _spendStatus;
  final BroadcastSpend? _broadcastSpend;
  final Future<bool> Function(String, String)? _protectObservedSpend;
  final Future<Result<String, WalletDiscoveryFailure>> Function(String)?
  _receiveAddress;
  final Stream<WalletRevisionState> _revisions;
  final Future<Result<void, WalletDiscoveryFailure>> Function(String)?
  _discoverWallet;
  final Future<void> Function(String, {required bool Function() isActive})?
  _pollWallet;
  final Stream<void> _syncFinished;
  final Stream<bool> _syncPassActivity;
  final bool Function()? _isSyncPassActive;
  final Future<Result<NetworkEnv?, WalletFailure>> Function()?
  _readDefaultWalletNetwork;
  final Future<Result<bool, WalletFailure>> Function()? _readTorRequirement;

  const WalletFacade(
    this._revisions, {
    this._nextReceiveAddress,
    this._spendStatus,
    this._receiveAddress,
    this._broadcastSpend,
    this._protectObservedSpend,
    this._discoverWallet,
    this._pollWallet,
    this._syncFinished = const Stream.empty(),
    this._syncPassActivity = const Stream.empty(),
    this._isSyncPassActive,
    this._readDefaultWalletNetwork,
    this._readTorRequirement,
  });

  /// The default wallet's environment, or null before a default wallet exists.
  Future<Result<NetworkEnv?, WalletFailure>> defaultWalletNetwork() async =>
      _readDefaultWalletNetwork?.call() ??
      const Err(WalletStorageFailure('wallet network capability unavailable'));

  /// Whether the default mainnet Bitcoin wallet requires Tor for its backup.
  Future<Result<bool, WalletFailure>> isTorRequired() async =>
      _readTorRequirement?.call() ??
      const Err(WalletStorageFailure('Tor requirement capability unavailable'));

  Future<Result<String, WalletDiscoveryFailure>> receiveAddress(
    String walletId,
  ) =>
      _receiveAddress?.call(walletId) ??
      Future.value(const Err(WalletDiscoveryUnavailableFailure()));

  Future<BitcoinSpendStatus> spendStatus(
    String walletId, {
    String? replacing,
  }) async =>
      _spendStatus?.call(walletId, replacing: replacing) ??
      BitcoinSpendStatus.unavailable;

  /// Broadcasts a signed transaction of [walletId] through `wallet.tx`,
  /// which checks its generation and inputs again under the guard. [built]
  /// carries the generation it was built at. A wallet of another [network]
  /// is refused before any admission or server.
  Future<Result<SpendReceipt, SyncFailure>> broadcastSpend(
    String walletId,
    SignedTransaction transaction, {
    required primitives.Network network,
    UnsignedSpend? built,
    SpendOwner? owner,
    String? replacing,
  }) async {
    final broadcast = _broadcastSpend;
    if (broadcast == null) return const Err(SyncUnsupportedNetworkFailure());
    return broadcast(
      walletId,
      transaction,
      network: network,
      built: built,
      owner: owner,
      replacing: replacing,
    );
  }

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
