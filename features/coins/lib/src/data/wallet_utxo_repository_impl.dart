import 'package:bull_logger/bull_logger.dart';
import 'package:coins/src/domain/coins_failure.dart';
import 'package:secrets/secrets.dart'
    show WalletInventory, WalletRegistrationNotFoundFailure;
import 'package:sync/sync.dart';
import 'package:coins/src/data/mappers/wallet_utxo_mapper.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Outpoint, Result;
import 'package:coins/src/domain/wallet_utxo.dart';
import 'package:coins/src/domain/repositories/wallet_utxo_repository.dart';
import 'package:labels/labels.dart';

class WalletUtxoRepositoryImpl implements WalletUtxoRepository {
  final WalletInventory _inventory;
  final Labels _labelsFacade;
  final Future<Result<Wallet, SyncFailure>> Function(WalletKey) _loadWallet;
  final Future<Result<Set<Outpoint>, SyncFailure>> Function()
  _readFrozenOutpoints;
  final Future<Result<void, SyncFailure>> Function(WalletKey, List<Outpoint>)
  _freezeWalletOutpoints;
  final Future<Result<void, SyncFailure>> Function(List<Outpoint>)
  _unfreezeOutpoints;

  WalletUtxoRepositoryImpl({
    required this._inventory,
    required this._labelsFacade,
    required this._loadWallet,
    required this._readFrozenOutpoints,
    required this._freezeWalletOutpoints,
    required this._unfreezeOutpoints,
  });

  /// The stored wallet's key, with the storage failure mapped to the sync
  /// vocabulary this repository speaks. The lookup lives here, not in the
  /// composition root: a missing registration and a failed read are distinct
  /// and both are coins storage boundaries.
  Future<WalletKey> _walletKey(String walletId) async =>
      switch (await _inventory.readWallet(walletId)) {
        Ok(:final value) => WalletKey(id: value.id, network: value.network),
        Err(failure: WalletRegistrationNotFoundFailure()) =>
          throw const WalletSnapshotException(SyncNotFoundFailure()),
        Err() => throw const WalletSnapshotException(SyncStorageFailure()),
      };

  static T _value<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  Future<Result<T, CoinsFailure>> _read<T>(
    Future<T> Function() operation,
    CoinsFailure Function(String) failure,
    String message,
  ) async {
    try {
      return Ok(await operation());
    } on Exception catch (error, trace) {
      log.warning(message, error: error.runtimeType, trace: trace);
      return Err(failure(error.runtimeType.toString()));
    }
  }

  Future<List<Label>> _fetchLabels(String reference) async =>
      (await _labelsFacade.fetch(reference: reference))
          .fold((labels) => labels, (_) => const <Label>[]);

  @override
  Future<Result<List<WalletUtxo>, CoinsFailure>> getWalletUtxos({
    required String walletId,
  }) => _read(
    () => _getWalletUtxos(walletId),
    CoinsLoadFailure.new,
    'Failed to load wallet coins',
  );

  Future<List<WalletUtxo>> _getWalletUtxos(String walletId) async {
    final key = await _walletKey(walletId);
    final wallet = _value(await _loadWallet(key));
    // An unavailable freeze policy must never publish apparently spendable coins.
    final coins = _value(wallet.coins.now.latest);

    final utxos = await Future.wait(
      coins.map((coin) async {
        final (txId: txId, vout: vout) = coin.outpoint;
        final labelModels = await _fetchLabels('$txId:$vout');
        final txLabels = await _fetchLabels(txId);
        List<Label> addressLabels;
        switch (coin) {
          case LiquidCoin():
            final (standardAddressLabels, confidentialAddressLabels) = await (
              _fetchLabels(coin.standardAddress),
              _fetchLabels(coin.confidentialAddress),
            ).wait;

            addressLabels = [
              ...standardAddressLabels,
              ...confidentialAddressLabels,
            ];
          case BitcoinCoin():
            final labels = await _fetchLabels(coin.address ?? '');
            addressLabels = labels;
        }

        return WalletUtxoMapper.toEntity(
          coin,
          walletId: walletId,
          labels: labelModels,
          txLabels: txLabels,
          addressLabels: addressLabels,
        );
      }).toList(),
    );

    return utxos;
  }

  @override
  Future<Result<void, CoinsFailure>> freezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _read(
    () async {
      final key = await _walletKey(walletId);
      _value(await _freezeWalletOutpoints(key, outpoints));
    },
    CoinsFreezeFailure.new,
    'Failed to freeze wallet coins',
  );

  @override
  Future<Result<void, CoinsFailure>> unfreezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _read(
    () async {
      _value(await _unfreezeOutpoints(outpoints));
    },
    CoinsUnfreezeFailure.new,
    'Failed to unfreeze wallet coins',
  );

  @override
  Future<Result<List<Outpoint>, CoinsFailure>> getAllFrozenOutpoints() => _read(
    () async => _value(await _readFrozenOutpoints()).toList(),
    CoinsLoadFailure.new,
    'Failed to load frozen outpoints',
  );
}
