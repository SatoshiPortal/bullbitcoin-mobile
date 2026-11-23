import 'package:sync/sync.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/coins/data/mappers/wallet_utxo_mapper.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Outpoint, Result;
import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:bb_mobile/features/coins/domain/repositories/wallet_utxo_repository.dart';
import 'package:labels/labels.dart';

class WalletUtxoRepositoryImpl implements WalletUtxoRepository {
  final WalletInventory _inventory;
  final Labels _labelsFacade;
  final Future<Result<Wallet, SyncFailure>> Function(WalletKey) _loadWallet;
  final CoinFreezes _freezes;

  WalletUtxoRepositoryImpl({
    required this._inventory,
    required this._labelsFacade,
    required this._loadWallet,
    required CoinFreezes freezesDatasource,
  }) : _freezes = freezesDatasource;

  Future<List<Label>> _fetchLabels(String reference) async =>
      (await _labelsFacade.fetch(reference: reference))
          .fold((labels) => labels, (_) => const <Label>[]);

  @override
  Future<List<WalletUtxo>> getWalletUtxos({required String walletId}) async {
    final key = await _readKey(walletId);
    final wallet = _readSync(await _loadWallet(key));
    // An unavailable freeze policy must never publish apparently spendable coins.
    final coins = _readSync(wallet.coins.now.latest);

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
  Future<void> freezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) async {
    await _freezes.freeze(await _readKey(walletId), outpoints);
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

  @override
  Future<void> unfreezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _freezes.unfreeze(outpoints);

  @override
  Future<List<Outpoint>> getAllFrozenOutpoints() async =>
      (await _freezes.getFrozenOutpoints()).toList();
}
