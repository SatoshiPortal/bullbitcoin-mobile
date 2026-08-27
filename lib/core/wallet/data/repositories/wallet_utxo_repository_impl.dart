import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

class WalletUtxoRepositoryImpl implements WalletUtxoRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final LabelsFacade _labelsFacade;
  final BdkWalletDatasource _bdkWalletDatasource;
  final LwkWalletDatasource _lwkWalletDatasource;
  final FrozenWalletUtxoDatasource _frozenWalletUtxoDatasource;

  WalletUtxoRepositoryImpl({
    required this._walletMetadataDatasource,
    required this._labelsFacade,
    required this._bdkWalletDatasource,
    required this._lwkWalletDatasource,
    required this._frozenWalletUtxoDatasource,
  });

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
            isTestnet: metadata.isTestnet,
            id: metadata.id,
          )
        : WalletModel.publicLwk(
            combinedCtDescriptor: metadata.externalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.id,
          );

    final utxoModels = metadata.isBitcoin
        ? await _bdkWalletDatasource.getUtxos(wallet: walletModel)
        : await _lwkWalletDatasource.getUtxos(wallet: walletModel);
    // `isFrozen` is matched by outpoint against the global frozen set (an
    // outpoint is globally unique, so it belongs to one wallet anyway). Frozen
    // rows for coins this wallet doesn't hold simply never match. Materialise
    // as a Set for O(1) membership — Outpoint is a record, so it has structural
    // equality/hashCode and keys the set directly.
    final frozenOutpoints = (await _frozenWalletUtxoDatasource.getAllFrozen())
        .map((row) => (txId: row.txId, vout: row.vout))
        .toSet();

    final utxos = await Future.wait(
      utxoModels.map((model) async {
        // Get labels for the UTXO if any
        final labelModels = await _labelsFacade.fetchByReference(
          model.labelRef,
        );
        final txLabels = await _labelsFacade.fetchByReference(model.txId);
        // Check if the UTXO is frozen
        final isFrozen = frozenOutpoints.contains((
          txId: model.txId,
          vout: model.vout,
        ));
        // Get the possible address labels for the UTXO
        List<Label> addressLabels;
        switch (model) {
          case LiquidWalletUtxoModel _:
            final (standardAddressLabels, confidentialAddressLabels) = await (
              _labelsFacade.fetchByReference(model.standardAddress),
              _labelsFacade.fetchByReference(model.confidentialAddress),
            ).wait;

            addressLabels = [
              ...standardAddressLabels,
              ...confidentialAddressLabels,
            ];
          case BitcoinWalletUtxoModel _:
            final labels = await _labelsFacade.fetchByReference(model.address);
            addressLabels = labels;
        }

        return WalletUtxoMapper.toEntity(
          model,
          walletId: walletId,
          labels: labelModels,
          txLabels: txLabels,
          addressLabels: addressLabels,
          isFrozen: isFrozen,
        );
      }).toList(),
    );

    return utxos;
  }

  @override
  Future<void> freezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) {
    return _frozenWalletUtxoDatasource.freezeOutpoints(
      walletId: walletId,
      outpoints: outpoints,
    );
  }

  @override
  Future<void> unfreezeUtxos({
    required String walletId,
    required List<Outpoint> outpoints,
  }) {
    return _frozenWalletUtxoDatasource.unfreezeOutpoints(
      walletId: walletId,
      outpoints: outpoints,
    );
  }

  @override
  Future<List<Outpoint>> getAllFrozenOutpoints() async {
    final rows = await _frozenWalletUtxoDatasource.getAllFrozen();
    return rows.map((row) => (txId: row.txId, vout: row.vout)).toList();
  }
}
