import 'package:bull_logger/bull_logger.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';

import '../domain/coins_failure.dart';
import '../domain/wallet_utxo.dart';
import 'wallet_utxo_mapper.dart';

class WalletUtxoRepository {
  final WalletInventory _inventory;
  final Labels _labels;
  final Future<Result<Wallet, SyncFailure>> Function(WalletKey) _loadWallet;
  final CoinFreezes _freezes;

  WalletUtxoRepository({
    required WalletInventory inventory,
    required Labels labelsFacade,
    required Future<Result<Wallet, SyncFailure>> Function(WalletKey) loadWallet,
    required CoinFreezes freezesDatasource,
  }) : _inventory = inventory,
       _labels = labelsFacade,
       _loadWallet = loadWallet,
       _freezes = freezesDatasource;

  Future<List<Label>> _fetchLabels(String reference) async =>
      (await _labels.fetch(reference: reference))
          .fold((labels) => labels, (_) => const <Label>[]);

  Future<Result<List<WalletUtxo>, CoinsFailure>> coins(String walletId) async {
    try {
      final key = await _readKey(walletId);
      final wallet = _readSync(await _loadWallet(key));
      // An unavailable freeze policy must never publish apparently spendable coins.
      final coins = _readSync(wallet.coins.now.latest);
      final utxos = await Future.wait(
        coins.map((coin) async {
          final (txId: txId, vout: vout) = coin.outpoint;
          final labels = await _fetchLabels('$txId:$vout');
          final txLabels = await _fetchLabels(txId);
          List<Label> addressLabels;
          switch (coin) {
            case LiquidCoin():
              final (standard, confidential) = await (
                _fetchLabels(coin.standardAddress),
                _fetchLabels(coin.confidentialAddress),
              ).wait;
              addressLabels = [...standard, ...confidential];
            case BitcoinCoin():
              addressLabels = await _fetchLabels(coin.address ?? '');
          }
          return WalletUtxoMapper.toEntity(
            coin,
            walletId: walletId,
            labels: labels,
            txLabels: txLabels,
            addressLabels: addressLabels,
          );
        }),
      );
      return Ok(utxos);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to load wallet coins',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return Err(CoinsLoadFailure(error.runtimeType.toString()));
    }
  }

  Future<Result<void, CoinsFailure>> freeze(
    String walletId,
    List<Outpoint> outpoints,
  ) async {
    try {
      await _freezes.freeze(await _readKey(walletId), outpoints);
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to freeze wallet coins',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return Err(CoinsFreezeFailure(error.runtimeType.toString()));
    }
  }

  Future<Result<void, CoinsFailure>> unfreeze(List<Outpoint> outpoints) async {
    try {
      await _freezes.unfreeze(outpoints);
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.warning(
        'Failed to unfreeze wallet coins',
        error: error.runtimeType,
        trace: stackTrace,
      );
      return Err(CoinsUnfreezeFailure(error.runtimeType.toString()));
    }
  }

  Future<WalletKey> _readKey(String walletId) async =>
      switch (await _inventory.readWallet(walletId)) {
        Ok(:final value) => WalletKey(id: value.id, network: value.network),
        Err(failure: WalletRegistrationNotFoundFailure()) =>
          throw const WalletSnapshotException(SyncNotFoundFailure()),
        Err() => throw const WalletSnapshotException(SyncStorageFailure()),
      };

  static T _readSync<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };
}
