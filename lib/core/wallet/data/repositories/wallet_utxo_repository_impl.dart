import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';

class WalletUtxoRepositoryImpl implements WalletUtxoRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final WalletDatasource _bdkWalletDatasource;
  final WalletDatasource _lwkWalletDatasource;
  final FrozenWalletUtxoDatasource _frozenWalletUtxoDatasource;
  final LabelStorageDatasource _labelStorageDatasource;

  WalletUtxoRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required WalletDatasource bdkWalletDatasource,
    required WalletDatasource lwkWalletDatasource,
    required FrozenWalletUtxoDatasource frozenWalletUtxoDatasource,
    required LabelStorageDatasource labelStorageDatasource,
  })  : _walletMetadataDatasource = walletMetadataDatasource,
        _bdkWalletDatasource = bdkWalletDatasource,
        _lwkWalletDatasource = lwkWalletDatasource,
        _frozenWalletUtxoDatasource = frozenWalletUtxoDatasource,
        _labelStorageDatasource = labelStorageDatasource;

  @override
  Future<List<WalletUtxo>> getWalletUtxos({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.get(walletId);

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

    final walletDatasource =
        metadata.isBitcoin ? _bdkWalletDatasource : _lwkWalletDatasource;
    final utxoModels = await walletDatasource.getUtxos(wallet: walletModel);
    final frozenUtxos = await _frozenWalletUtxoDatasource.getFrozenWalletUtxos(
      walletId: walletId,
    );

    final utxos = await Future.wait(
      utxoModels.map((model) async {
        // Get labels for the UTXO if any
        final labelModels = await _labelStorageDatasource.fetchByRef(
          Entity.output,
          model.labelRef,
        );
        // Check if the UTXO is frozen
        final isFrozen = frozenUtxos.any(
          (frozenUtxo) =>
              frozenUtxo.txId == model.txId && frozenUtxo.vout == model.vout,
        );
        // Get the possible address labels for the UTXO
        List<LabelModel> addressLabels;
        switch (model) {
          case LiquidWalletUtxoModel _:
            final (standardAddressLabels, confidentialAddressLabels) = await (
              _labelStorageDatasource.fetchByRef(
                Entity.address,
                model.standardAddress,
              ),
              _labelStorageDatasource.fetchByRef(
                Entity.address,
                model.confidentialAddress,
              )
            ).wait;

            addressLabels = [
              ...standardAddressLabels,
              ...confidentialAddressLabels,
            ];
          case BitcoinWalletUtxoModel _:
            addressLabels = await _labelStorageDatasource.fetchByRef(
              Entity.address,
              model.address,
            );
        }

        return WalletUtxoMapper.toEntity(
          model,
          walletId: walletId,
          labels: labelModels.map((model) => model.label).toList(),
          addressLabels: addressLabels.map((model) => model.label).toList(),
          isFrozen: isFrozen,
        );
      }).toList(),
    );

    return utxos;
  }
}
