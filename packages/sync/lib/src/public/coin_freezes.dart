import 'package:primitives/primitives.dart';

import '../../sync.dart' show WalletSnapshotException;
import '../../sync.dart' as sync;

/// User freezes, read and changed through sync. Every call throws
/// [WalletSnapshotException] with the failure: a freeze store that cannot
/// answer is never read as "nothing frozen".
class CoinFreezes {
  final Future<sync.Sync> Function() _sync;

  CoinFreezes({required this._sync});

  /// Every freeze with its attribution (wallet origin, or empty).
  Future<List<sync.FrozenOutpoint>> getAllFrozen() async =>
      _value(await (await _sync()).coins.listFrozen());

  /// The outpoints no spend may use, read from the store now.
  Future<Set<Outpoint>> getFrozenOutpoints() async => {
    for (final row in await getAllFrozen()) row.outpoint,
  };

  /// Freezes [outpoints] through the wallet's handle, attributed to it.
  Future<void> freeze(sync.WalletKey key, List<Outpoint> outpoints) async {
    final wallet = _value(await (await _sync()).wallet(key));
    for (final outpoint in outpoints) {
      _value(await wallet.coins.freeze(outpoint));
    }
  }

  /// Freezes outpoints attributed as given, wallet known or not (BIP329).
  Future<void> freezeAttributed(List<sync.FrozenOutpoint> rows) async {
    final coins = (await _sync()).coins;
    for (final row in rows) {
      _value(await coins.freeze(row.outpoint, origin: row.origin));
    }
  }

  /// Removes every attribution of [outpoints].
  Future<void> unfreeze(List<Outpoint> outpoints) async {
    final coins = (await _sync()).coins;
    for (final outpoint in outpoints) {
      _value(await coins.unfreeze(outpoint));
    }
  }

  static T _value<T>(Result<T, sync.SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };
}
