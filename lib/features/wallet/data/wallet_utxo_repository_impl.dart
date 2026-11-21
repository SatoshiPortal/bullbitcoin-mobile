import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/sync_freezes_datasource.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:labels/labels.dart';

class WalletUtxoRepositoryImpl implements WalletUtxoRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final Labels _labelsFacade;
  final SyncWalletValuesDatasource _values;
  final SyncFreezesDatasource _freezes;

  WalletUtxoRepositoryImpl({
    required this._walletMetadataDatasource,
    required this._labelsFacade,
    required SyncWalletValuesDatasource walletValuesDatasource,
    required SyncFreezesDatasource freezesDatasource,
  }) : _values = walletValuesDatasource,
       _freezes = freezesDatasource;

  Future<List<Label>> _fetchLabels(String reference) async =>
      (await _labelsFacade.fetch(reference: reference))
          .fold((labels) => labels, (_) => const <Label>[]);

  @override
  Future<List<WalletUtxo>> getWalletUtxos({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    final walletModel = metadata.isBitcoin
        ? WalletModel.publicBdk(
            externalDescriptor: metadata.externalPublicDescriptor,
            internalDescriptor: metadata.internalPublicDescriptor,
            network: metadata.network,
            id: metadata.id,
          )
        : WalletModel.publicLwk(
            combinedCtDescriptor: metadata.externalPublicDescriptor,
            network: metadata.network,
            id: metadata.id,
          );

    // Sync publishes each coin with its frozen state: a freeze is global by
    // outpoint, whichever wallet or import froze it.
    final coins = await _values.getCoins(wallet: walletModel);

    final utxos = await Future.wait(
      coins.map((coin) async {
        final model = coin.model;
        // Get labels for the UTXO if any
        final labelModels = await _fetchLabels(model.labelRef);
        final txLabels = await _fetchLabels(model.txId);
        // Get the possible address labels for the UTXO
        List<Label> addressLabels;
        switch (model) {
          case LiquidWalletUtxoModel _:
            final (standardAddressLabels, confidentialAddressLabels) = await (
              _fetchLabels(model.standardAddress),
              _fetchLabels(model.confidentialAddress),
            ).wait;

            addressLabels = [
              ...standardAddressLabels,
              ...confidentialAddressLabels,
            ];
          case BitcoinWalletUtxoModel _:
            final labels = await _fetchLabels(model.address);
            addressLabels = labels;
        }

        return WalletUtxoMapper.toEntity(
          model,
          walletId: walletId,
          labels: labelModels,
          txLabels: txLabels,
          addressLabels: addressLabels,
          isFrozen: coin.frozen,
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
    final metadata = await _walletMetadataDatasource.fetch(walletId);
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
