export 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';

export '../domain/wallet.dart' show Network;
export '../domain/network_x.dart' show NetworkX;

import 'package:sync/sync.dart';

import 'package:sync/write.dart' show BroadcastSpend;

import 'package:primitives/primitives.dart' as primitives show Network;
import 'package:primitives/primitives.dart' show Result, Err;

export 'package:primitives/primitives.dart' show NetworkEnv, Result;

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

/// Legacy Send access to the writer's guarded broadcast operations.
final class WalletFacade {
  final Future<BitcoinSpendStatus> Function(String, {String? replacing})?
  _spendStatus;
  final BroadcastSpend? _broadcastSpend;
  final Future<bool> Function(String, String)? _protectObservedSpend;

  const WalletFacade({
    this._spendStatus,
    this._broadcastSpend,
    this._protectObservedSpend,
  });

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
}
