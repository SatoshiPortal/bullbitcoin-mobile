import 'dart:typed_data';

import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, Ok, Result;
import 'package:sync/sync.dart' as sync;

/// Reads through the native runtime while the application still resolves
/// wallet IDs through the legacy catalog.
class SyncWalletValuesDatasource {
  final Future<sync.Wallet> Function(sync.WalletKey) _load;

  SyncWalletValuesDatasource({required this._load});

  T _value<T>(Result<T, sync.SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw sync.WalletSnapshotException(failure),
  };

  Future<sync.Balances> getBalance({required sync.WalletKey key}) async =>
      _value((await _load(key)).balances.now.latest);

  /// The unspent coins exactly at the latest committed revision, for a
  /// protocol decision. Retries briefly while the writer is busy.
  Future<sync.CoinList> getExactUtxos({required sync.WalletKey key}) async {
    final handle = await _load(key);
    return _value(await handle.readExactUnspent());
  }

  /// Exact ownership at the latest committed revision: scripts the index
  /// derives and outputs held, spent ones included. Retries briefly while
  /// the writer is busy; never answers from an older revision.
  Future<sync.OwnershipIndex> getOwnership({
    required sync.WalletKey key,
  }) async {
    final handle = await _load(key);
    return _value(await handle.readExactOwnership());
  }

  Future<bool> isMine(Uint8List script, {required sync.WalletKey key}) async =>
      (await getOwnership(key: key)).ownsScript(script);

  Future<bool> areAddressesMine(
    List<String> addresses, {
    required sync.WalletKey key,
  }) async {
    final network = key.network;
    if (network is! BitcoinNetwork) {
      throw const sync.WalletSnapshotException(
        sync.SyncUnsupportedNetworkFailure(),
      );
    }
    final ownership = await getOwnership(key: key);
    for (final address in addresses) {
      switch (sync.bitcoinAddressScript(address, network)) {
        case Ok(value: final script) when ownership.ownsScript(script):
          continue;
        case Ok():
          return false;
        case Err(:final failure):
          throw sync.WalletSnapshotException(failure);
      }
    }
    return true;
  }
}
