import 'package:bb_mobile/core/labels/data/label_model.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/transaction_output_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/utxo_repository.dart';

class UtxoRepositoryImpl implements UtxoRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final WalletDatasource _bdkWalletDatasource;
  final WalletDatasource _lwkWalletDatasource;
  final FrozenUtxoDatasource _frozenUtxoDatasource;
  final LabelStorageDatasource _labelStorageDatasource;

  UtxoRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required WalletDatasource bdkWalletDatasource,
    required WalletDatasource lwkWalletDatasource,
    required FrozenUtxoDatasource frozenUtxoDatasource,
    required LabelStorageDatasource labelStorageDatasource,
  })  : _walletMetadataDatasource = walletMetadataDatasource,
        _bdkWalletDatasource = bdkWalletDatasource,
        _lwkWalletDatasource = lwkWalletDatasource,
        _frozenUtxoDatasource = frozenUtxoDatasource,
        _labelStorageDatasource = labelStorageDatasource;

  @override
  Future<List<TransactionOutput>> getUtxos({required String walletId}) async {
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
    final frozenUtxos =
        await _frozenUtxoDatasource.getFrozenUtxos(walletId: walletId);

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
          case LiquidTransactionOutputModel _:
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
          case BitcoinTransactionOutputModel _:
            addressLabels = await _labelStorageDatasource.fetchByRef(
              Entity.address,
              model.address,
            );
        }

        return TransactionOutputMapper.toEntity(
          model,
          labels: labelModels.map((model) => model.label).toList(),
          isFrozen: isFrozen,
          addressLabels: addressLabels.map((model) => model.label).toList(),
        );
      }).toList(),
    );

    return utxos;
  }
}
