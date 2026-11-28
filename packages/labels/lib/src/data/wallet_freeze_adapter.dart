import 'package:labels/src/domain/wallet_freeze_port.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show SecretFailure;
import 'package:sync/sync.dart';

typedef ReadOwnedOutpointsInSession =
    Future<Result<List<Outpoint>, SecretFailure>> Function(
      Future<List<Outpoint>> Function() read,
    );

/// Implements [WalletFreezePort] over the freezes sync owns. Every call
/// throws [WalletSnapshotException] when sync cannot answer.
class WalletFreezeAdapter implements WalletFreezePort {
  final Future<Result<List<FrozenOutpoint>, SyncFailure>> Function()
  _listAttributedFreezes;
  final Future<Result<void, SyncFailure>> Function(List<FrozenOutpoint>)
  _freezeAttributedOutpoints;
  final Future<Wallet> Function(String walletId) _openWallet;
  final ReadOwnedOutpointsInSession _readInSession;

  WalletFreezeAdapter({
    required this._listAttributedFreezes,
    required this._freezeAttributedOutpoints,
    required this._openWallet,
    required this._readInSession,
  });

  @override
  Future<List<({String walletId, String txId, int vout})>>
  getAllFrozen() async => switch (await _listAttributedFreezes()) {
    Ok(:final value) => [
      for (final row in value)
        (
          walletId: row.origin,
          txId: row.outpoint.txId,
          vout: row.outpoint.vout,
        ),
    ],
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  @override
  Future<void> freeze(
    List<({String? walletId, String txId, int vout})> outputs,
  ) async {
    // The origin is kept as given: a null one stores empty, inert until a
    // wallet holds the coin, matched by outpoint either way. A known wallet's
    // freeze uses the same attribution as `wallet.coins.freeze`.
    final result = await _freezeAttributedOutpoints([
      for (final o in outputs)
        FrozenOutpoint((txId: o.txId, vout: o.vout), origin: o.walletId ?? ''),
    ]);
    if (result case Err(:final failure)) {
      throw WalletSnapshotException(failure);
    }
  }

  @override
  Future<List<Outpoint>> getOwnedOutpoints({required String walletId}) async =>
      switch (await _readInSession(() => _readOwnedOutpoints(walletId))) {
        Ok(:final value) => value,
        Err() => throw const WalletSnapshotException(SyncStorageFailure()),
      };

  // This guards publication of the read, not the caller's later freeze write.
  Future<List<Outpoint>> _readOwnedOutpoints(String walletId) async {
    final wallet = await _openWallet(walletId);
    if (await wallet.load() case Err(:final failure)) {
      throw WalletSnapshotException(failure);
    }
    final snapshot = wallet.coins.now;
    final coins = snapshot.data;
    if (coins == null) {
      throw WalletSnapshotException(
        snapshot.failure ?? const SyncBusyFailure(),
      );
    }
    return [for (final coin in coins) coin.outpoint];
  }
}
