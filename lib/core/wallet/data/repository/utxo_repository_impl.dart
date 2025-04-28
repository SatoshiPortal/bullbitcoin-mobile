import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/utils/address_script_conversions.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet/wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/address_model.dart';
import 'package:bb_mobile/core/wallet/data/models/utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/utxo_repository.dart';

class UtxoRepositoryImpl implements UtxoRepository {
  final SqliteDatasource _sqlite;
  final WalletDatasource _bdkWalletDatasource;
  final WalletDatasource _lwkWalletDatasource;
  final FrozenUtxoDatasource _frozenUtxoDatasource;

  UtxoRepositoryImpl({
    required SqliteDatasource sqliteDatasource,
    required WalletDatasource bdkWalletDatasource,
    required WalletDatasource lwkWalletDatasource,
    required FrozenUtxoDatasource frozenUtxoDatasource,
  })  : _sqlite = sqliteDatasource,
        _bdkWalletDatasource = bdkWalletDatasource,
        _lwkWalletDatasource = lwkWalletDatasource,
        _frozenUtxoDatasource = frozenUtxoDatasource;

  @override
  Future<List<Utxo>> getUtxos({required String walletId}) async {
    final metadata = await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
        .getSingleOrNull();

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
        // Get the address for the UTXO
        final address = await _getAddressOfUtxo(
          model,
          walletDatasource: walletDatasource,
          walletModel: walletModel,
          isLiquid: metadata.isLiquid,
        );
        // Get labels for the UTXO if any
        final labelModels = await _sqlite.managers.labels
            .filter((l) => l.ref(model.toRef()))
            .get();

        // Check if the UTXO is frozen
        final isFrozen = frozenUtxos.any(
          (frozenUtxo) =>
              frozenUtxo.txId == model.txId && frozenUtxo.vout == model.vout,
        );
        return model.toEntity(
          isFrozen: isFrozen,
          address: address,
          labels: labelModels.map((model) => model.label).toList(),
        );
      }).toList(),
    );

    return utxos;
  }

  Future<Address?> _getAddressOfUtxo(
    UtxoModel utxo, {
    required WalletDatasource walletDatasource,
    required WalletModel walletModel,
    required bool isLiquid,
  }) async {
    final utxoAddress = isLiquid
        ? await AddressScriptConversions.liquidAddressFromScript(
            utxo.scriptPubkey.toHexString(),
            isTestnet: walletModel.isTestnet,
          )
        : await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
            utxo.scriptPubkey,
            isTestnet: walletModel.isTestnet,
          );
    final lastUnusedReceiveAddress =
        await walletDatasource.getLastUnusedAddress(wallet: walletModel);
    final receiveAddresses = await walletDatasource.getReceiveAddresses(
      wallet: walletModel,
      limit: lastUnusedReceiveAddress.index + 1,
      offset: 0,
    );
    final matchingReceiveAddress = receiveAddresses
        .where((addressModel) => addressModel.address == utxoAddress);
    if (matchingReceiveAddress.isNotEmpty) {
      final addressModel = matchingReceiveAddress.first;

      return isLiquid
          ? Address.liquid(
              index: addressModel.index,
              standard: (addressModel as LiquidAddressModel).standard,
              confidential: addressModel.confidential,
              keyChain: AddressKeyChain.external,
              status: AddressStatus.used,
              walletId: walletModel.id,
            )
          : Address.bitcoin(
              index: addressModel.index,
              address: addressModel.address,
              keyChain: AddressKeyChain.external,
              status: AddressStatus.used,
              walletId: walletModel.id,
            );
    }

    final lastUnusedChangeAddress = await walletDatasource.getLastUnusedAddress(
      wallet: walletModel,
      isChange: true,
    );
    final changeAddresses = await walletDatasource.getChangeAddresses(
      wallet: walletModel,
      limit: lastUnusedChangeAddress.index + 1,
      offset: 0,
    );
    final matchingChangeAddress = changeAddresses
        .where((addressModel) => addressModel.address == utxoAddress);
    if (matchingChangeAddress.isNotEmpty) {
      final addressModel = matchingChangeAddress.first;

      return isLiquid
          ? Address.liquid(
              index: addressModel.index,
              standard: (addressModel as LiquidAddressModel).standard,
              confidential: addressModel.confidential,
              keyChain: AddressKeyChain.internal,
              status: AddressStatus.used,
              walletId: walletModel.id,
            )
          : Address.bitcoin(
              index: addressModel.index,
              address: addressModel.address,
              keyChain: AddressKeyChain.internal,
              status: AddressStatus.used,
              walletId: walletModel.id,
            );
    }
    // If no matching address is found, return null
    return null;
  }
}
