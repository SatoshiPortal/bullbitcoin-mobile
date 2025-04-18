import 'package:bb_mobile/core/utxo/data/datasources/frozen_utxo_datasource.dart';
import 'package:bb_mobile/core/utxo/data/datasources/utxo_datasource.dart';
import 'package:bb_mobile/core/utxo/domain/entities/utxo.dart';
import 'package:bb_mobile/core/utxo/domain/repositories/utxo_repository.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';

class UtxoRepositoryImpl implements UtxoRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final UtxoDatasource _bdkWalletDatasource;
  final UtxoDatasource _lwkWalletDatasource;
  final FrozenUtxoDatasource _frozenUtxoDatasource;

  UtxoRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required UtxoDatasource bdkWalletDatasource,
    required UtxoDatasource lwkWalletDatasource,
    required FrozenUtxoDatasource frozenUtxoDatasource,
  })  : _walletMetadataDatasource = walletMetadataDatasource,
        _bdkWalletDatasource = bdkWalletDatasource,
        _lwkWalletDatasource = lwkWalletDatasource,
        _frozenUtxoDatasource = frozenUtxoDatasource;

  @override
  Future<List<Utxo>> getUtxos({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.get(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    final walletModel = metadata.isBitcoin
        ? PublicBdkWalletModel(
            externalDescriptor: metadata.externalPublicDescriptor,
            internalDescriptor: metadata.internalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.id,
          )
        : PublicLwkWalletModel(
            combinedCtDescriptor: metadata.externalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.id,
          );

    final walletDatasource =
        metadata.isBitcoin ? _bdkWalletDatasource : _lwkWalletDatasource;
    final utxoModels = await walletDatasource.getUtxos(wallet: walletModel);
    final frozenUtxos =
        await _frozenUtxoDatasource.getFrozenUtxos(walletId: walletId);

    final utxos = utxoModels.map((model) {
      // Check if the UTXO is frozen
      final isFrozen = frozenUtxos.any(
        (frozenUtxo) =>
            frozenUtxo.txId == model.txId && frozenUtxo.vout == model.vout,
      );
      return model.toEntity(isFrozen: isFrozen);
    }).toList();

    return utxos;
  }
}
