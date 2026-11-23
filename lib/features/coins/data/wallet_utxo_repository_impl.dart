import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:sync/sync.dart' show CoinFreezes;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:sync/sync.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/coins/data/mappers/wallet_utxo_mapper.dart';
import 'package:primitives/primitives.dart' show Outpoint, Result;
import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:bb_mobile/features/coins/domain/repositories/wallet_utxo_repository.dart';
import 'package:labels/labels.dart';

class WalletUtxoRepositoryImpl implements WalletUtxoRepository {
  final WalletRegistrations _walletRegistrations;
  final Labels _labelsFacade;
  final Future<Result<Wallet, SyncFailure>> Function(WalletKey) _loadWallet;
  final CoinFreezes _freezes;

  WalletUtxoRepositoryImpl({
    required this._walletRegistrations,
    required this._labelsFacade,
    required this._loadWallet,
    required CoinFreezes freezesDatasource,
  }) : _freezes = freezesDatasource;

  Future<List<Label>> _fetchLabels(String reference) async =>
      (await _labelsFacade.fetch(reference: reference))
          .fold((labels) => labels, (_) => const <Label>[]);

  @override
  Future<List<WalletUtxo>> getWalletUtxos({required String walletId}) async {
    final metadata = await _walletRegistrations.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    final key = WalletKey(id: metadata.id, network: metadata.network.shared);
    final wallet = WalletSyncBinding.value(await _loadWallet(key));
    // An unavailable freeze policy must never publish apparently spendable coins.
    final coins = WalletSyncBinding.value(wallet.coins.now.latest);

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
    final metadata = await _walletRegistrations.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    await _freezes.freeze(
      WalletKey(id: metadata.id, network: metadata.network.shared),
      outpoints,
    );
  }

  @override
  Future<void> unfreezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) => _freezes.unfreeze(outpoints);

  @override
  Future<List<Outpoint>> getAllFrozenOutpoints() async =>
      (await _freezes.getFrozenOutpoints()).toList();
}
