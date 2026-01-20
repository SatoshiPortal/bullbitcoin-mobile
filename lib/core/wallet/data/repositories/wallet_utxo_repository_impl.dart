import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
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
    required WalletMetadataDatasource walletMetadataDatasource,
    required LabelsFacade labelsFacade,
    required BdkWalletDatasource bdkWalletDatasource,
    required LwkWalletDatasource lwkWalletDatasource,
    required FrozenWalletUtxoDatasource frozenWalletUtxoDatasource,
  }) : _labelsFacade = labelsFacade,
       _walletMetadataDatasource = walletMetadataDatasource,
       _bdkWalletDatasource = bdkWalletDatasource,
       _lwkWalletDatasource = lwkWalletDatasource,
       _frozenWalletUtxoDatasource = frozenWalletUtxoDatasource;

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
    final frozenUtxos = await _frozenWalletUtxoDatasource.getFrozenWalletUtxos(
      walletId: walletId,
    );

    final utxos = await Future.wait(
      utxoModels.map((model) async {
        // Get labels for the UTXO if any
        final labelModels = await _labelsFacade.fetchByReference(
          model.labelRef,
        );
        final txLabels = await _labelsFacade.fetchByReference(model.txId);
        // Check if the UTXO is frozen
        final isFrozen = frozenUtxos.any(
          (frozenUtxo) =>
              frozenUtxo.txId == model.txId && frozenUtxo.vout == model.vout,
        );
        // Get the possible address labels for the UTXO
        List<String> addressLabels;
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
            addressLabels = await _labelsFacade.fetchByReference(model.address);
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
}
