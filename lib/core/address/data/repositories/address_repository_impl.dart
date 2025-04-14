import 'package:bb_mobile/core/address/data/datasources/address_datasource.dart';
import 'package:bb_mobile/core/address/domain/entities/address.dart';
import 'package:bb_mobile/core/address/domain/repositories/address_repository.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';

class AddressRepositoryImpl implements AddressRepository {
  final WalletMetadataDatasource _walletMetadata;
  final AddressDatasource _bdkWallet;
  final AddressDatasource _lwkWallet;

  AddressRepositoryImpl({
    required WalletMetadataDatasource walletMetadataDatasource,
    required AddressDatasource bdkWalletDatasource,
    required AddressDatasource lwkWalletDatasource,
  })  : _walletMetadata = walletMetadataDatasource,
        _bdkWallet = bdkWalletDatasource,
        _lwkWallet = lwkWalletDatasource;

  @override
  Future<Address> getNewAddress({required String origin}) async {
    final metadata = await _walletMetadata.get(origin);

    if (metadata == null) {
      throw Exception('Wallet metadata not found');
    }

    final walletModel = metadata.isBitcoin
        ? PublicBdkWalletModel(
            externalDescriptor: metadata.externalPublicDescriptor,
            internalDescriptor: metadata.internalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.origin,
          )
        : PublicLwkWalletModel(
            combinedCtDescriptor: metadata.externalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.origin,
          );

    final walletDatasource = metadata.isBitcoin ? _bdkWallet : _lwkWallet;

    final addressModel = await walletDatasource.getNewAddress(
      wallet: walletModel,
    );

    final address = addressModel.toEntity(
      origin: origin,
      keyChain: AddressKeyChain.external,
      status: AddressStatus.unused,
    );

    return address;
  }

  @override
  Future<Address> getLastUnusedAddress({required String origin}) async {
    final metadata = await _walletMetadata.get(origin);

    if (metadata == null) {
      throw Exception('Wallet metadata not found');
    }

    final walletModel = metadata.isBitcoin
        ? PublicBdkWalletModel(
            externalDescriptor: metadata.externalPublicDescriptor,
            internalDescriptor: metadata.internalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.origin,
          )
        : PublicLwkWalletModel(
            combinedCtDescriptor: metadata.externalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.origin,
          );
    final walletDatasource = metadata.isBitcoin ? _bdkWallet : _lwkWallet;

    final addressModel = await walletDatasource.getLastUnusedAddress(
      wallet: walletModel,
    );

    final address = addressModel.toEntity(
      origin: origin,
      keyChain: AddressKeyChain.external,
      status: AddressStatus.unused,
    );

    return address;
  }

  @override
  Future<List<Address>> getAddresses({
    required String origin,
    required int limit,
    required int offset,
    required AddressKeyChain keyChain,
  }) async {
    final metadata = await _walletMetadata.get(origin);

    if (metadata == null) {
      throw Exception('Wallet metadata not found');
    }

    final walletModel = metadata.isBitcoin
        ? PublicBdkWalletModel(
            externalDescriptor: metadata.externalPublicDescriptor,
            internalDescriptor: metadata.internalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.origin,
          )
        : PublicLwkWalletModel(
            combinedCtDescriptor: metadata.externalPublicDescriptor,
            isTestnet: metadata.isTestnet,
            id: metadata.origin,
          );
    final walletDatasource = metadata.isBitcoin ? _bdkWallet : _lwkWallet;

    final addressModels = keyChain == AddressKeyChain.external
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
      addressModels.map(
        (model) async {
          final isUsed = await walletDatasource.isAddressUsed(
            model.address,
            wallet: walletModel,
          );
          final balance = await walletDatasource.getAddressBalanceSat(
            model.address,
            wallet: walletModel,
          );

          return model.toEntity(
            origin: origin,
            keyChain: keyChain,
            status: isUsed ? AddressStatus.used : AddressStatus.unused,
            balanceSat: balance.toInt(),
          );
        },
      ),
    );

    return addresses;
  }
}
