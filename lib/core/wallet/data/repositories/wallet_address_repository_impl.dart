import 'package:bb_mobile/core/wallet/data/datasources/wallet/wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_address_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_address_repository.dart';

class WalletAddressRepositoryImpl implements WalletAddressRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final WalletDatasource _bdkWallet;
  final WalletDatasource _lwkWallet;

  WalletAddressRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required WalletDatasource bdkWalletDatasource,
    required WalletDatasource lwkWalletDatasource,
  }) : _walletMetadataDatasource = walletMetadataDatasource,
       _bdkWallet = bdkWalletDatasource,
       _lwkWallet = lwkWalletDatasource;

  @override
  Future<WalletAddress> getNewAddress({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found');
    }

    final walletModel =
        metadata.isBitcoin
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

    final walletDatasource = metadata.isBitcoin ? _bdkWallet : _lwkWallet;

    final walletAddressModel = await walletDatasource.getNewAddress(
      wallet: walletModel,
    );

    final address = WalletAddressMapper.toEntity(
      walletAddressModel,
      walletId: walletId,
      keyChain: WalletAddressKeyChain.external,
      status: WalletAddressStatus.unused,
    );

    return address;
  }

  @override
  Future<WalletAddress> getLastUnusedAddress({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) throw Exception('Wallet metadata not found');

    final walletModel =
        metadata.isBitcoin
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
    final walletDatasource = metadata.isBitcoin ? _bdkWallet : _lwkWallet;

    final walletAddressModel = await walletDatasource.getLastUnusedAddress(
      wallet: walletModel,
    );

    final address = WalletAddressMapper.toEntity(
      walletAddressModel,
      walletId: walletId,
      keyChain: WalletAddressKeyChain.external,
      status: WalletAddressStatus.unused,
    );

    return address;
  }

  @override
  Future<List<WalletAddress>> getAddresses({
    required String walletId,
    required int limit,
    required int offset,
    required WalletAddressKeyChain keyChain,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) throw Exception('Wallet metadata not found');

    final walletModel =
        metadata.isBitcoin
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
    final walletDatasource = metadata.isBitcoin ? _bdkWallet : _lwkWallet;

    final walletAddressModels =
        keyChain == WalletAddressKeyChain.external
            ? await walletDatasource.getReceiveAddresses(
              wallet: walletModel,
              limit: limit,
              offset: offset,
            )
            : await walletDatasource.getChangeAddresses(
              wallet: walletModel,
              limit: limit,
              offset: offset,
            );

    final addresses = await Future.wait(
      walletAddressModels.map((model) async {
        final isUsed = await walletDatasource.isAddressUsed(
          model.address,
          wallet: walletModel,
        );
        final balance = await walletDatasource.getAddressBalanceSat(
          model.address,
          wallet: walletModel,
        );

        return WalletAddressMapper.toEntity(
          model,
          walletId: walletId,
          keyChain: keyChain,
          status:
              isUsed ? WalletAddressStatus.used : WalletAddressStatus.unused,
          balanceSat: balance.toInt(),
        );
      }),
    );

    return addresses;
  }
}
