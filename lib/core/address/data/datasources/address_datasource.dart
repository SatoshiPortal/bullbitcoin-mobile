import 'package:bb_mobile/core/address/data/models/address_model.dart';
import 'package:bb_mobile/core/wallet/data/models/public_wallet_model.dart';

abstract class AddressDatasource {
  Future<AddressModel> getNewAddress({
    required PublicWalletModel wallet,
  });
  Future<AddressModel> getLastUnusedAddress({
    required PublicWalletModel wallet,
  });
  Future<AddressModel> getAddressByIndex(
    int index, {
    required PublicWalletModel wallet,
  });
  Future<List<AddressModel>> getReceiveAddresses({
    required PublicWalletModel wallet,
    required int limit,
    required int offset,
  });
  Future<List<AddressModel>> getChangeAddresses({
    required PublicWalletModel wallet,
    required int limit,
    required int offset,
  });
  Future<bool> isAddressUsed(
    String address, {
    required PublicWalletModel wallet,
  });
  Future<BigInt> getAddressBalanceSat(
    String address, {
    required PublicWalletModel wallet,
  });
}
