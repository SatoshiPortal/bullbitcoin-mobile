import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';

import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';

import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, Ok, Result;
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' as sync;

/// Reads through the native runtime while the application still resolves
/// wallet IDs through the legacy catalog.
class SyncWalletValuesDatasource {
  final Future<sync.Wallet> Function(sync.WalletKey) _load;

  SyncWalletValuesDatasource({required this._load});

  Future<sync.Balances> getBalance({required sync.WalletKey key}) async =>
      WalletCatalogPortImpl.value((await _load(key)).balances.now.latest);

  /// Number of L-BTC coins, the count that matters for LWK's input limit.
  Future<int> getLbtcUtxoCount({required sync.WalletKey key}) async =>
      WalletCatalogPortImpl.value((await _load(key)).coins.now.latest).length;

  /// The unspent coins exactly at the latest committed revision, for a
  /// protocol decision. Retries briefly while the writer is busy.
  Future<sync.CoinList> getExactUtxos({required sync.WalletKey key}) async {
    final handle = await _load(key);
    return _exact(handle.unspent);
  }

  /// Exact ownership at the latest committed revision: scripts the index
  /// derives and outputs held, spent ones included. Retries briefly while
  /// the writer is busy; never answers from an older revision.
  Future<sync.OwnershipIndex> getOwnership({
    required sync.WalletKey key,
  }) async {
    final handle = await _load(key);
    return _exact(handle.ownership);
  }

  Future<bool> isMine(Uint8List script, {required sync.WalletKey key}) async =>
      (await getOwnership(key: key)).ownsScript(script);

  Future<bool> areAddressesMine(
    List<String> addresses, {
    required sync.WalletKey key,
  }) async {
    final network = key.network;
    if (network is! BitcoinNetwork) {
      throw const WalletSnapshotException(sync.SyncUnsupportedNetworkFailure());
    }
    final ownership = await getOwnership(key: key);
    for (final address in addresses) {
      switch (sync.bitcoinAddressScript(address, network)) {
        case Ok(value: final script) when ownership.ownsScript(script):
          continue;
        case Ok():
          return false;
        case Err(:final failure):
          throw WalletSnapshotException(failure);
      }
    }
    return true;
  }

  Future<List<WalletUtxoModel>> getUtxos({required sync.WalletKey key}) async =>
      [
        for (final coin in WalletCatalogPortImpl.value(
          (await _load(key)).coins.now.latest,
        ))
          _utxo(coin),
      ];

  /// The coins with their frozen state, as sync publishes them. Throws
  /// while the freezes are unknown: a coin never reads as unfrozen.
  Future<List<({WalletUtxoModel model, bool frozen})>> getCoins({
    required sync.WalletKey key,
  }) async => [
    for (final coin in WalletCatalogPortImpl.value(
      (await _load(key)).coins.now.latest,
    ))
      (model: _utxo(coin), frozen: coin.frozen),
  ];

  static Future<T> _exact<T>(
    Future<Result<T, sync.SyncFailure>> Function() query,
  ) async {
    for (var attempt = 1; ; attempt++) {
      switch (await query()) {
        case Ok(:final value):
          return value;
        case Err(failure: sync.SyncBusyFailure()) when attempt < 5:
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        case Err(:final failure):
          throw WalletSnapshotException(failure);
      }
    }
  }

  static WalletUtxoModel _utxo(sync.Coin coin) => switch (coin) {
    sync.BitcoinCoin() => WalletUtxoModel.bitcoin(
      txId: coin.outpoint.txId,
      vout: coin.outpoint.vout,
      amountSat: coin.amountSat,
      scriptPubkey: Uint8List.fromList(coin.scriptPubkey),
      // A wallet coin always has an address form; keep the old fallback.
      address: coin.address ?? '',
      isExternalKeyChain: coin.keychain == sync.Keychain.external,
      confirmations: coin.confirmations,
    ),
    sync.LiquidCoin() => WalletUtxoModel.liquid(
      txId: coin.outpoint.txId,
      vout: coin.outpoint.vout,
      amountSat: coin.amountSat,
      scriptPubkey: coin.scriptPubkey,
      standardAddress: coin.standardAddress,
      confidentialAddress: coin.confidentialAddress,
      blockHeight: coin.blockHeight,
    ),
  };
}
