import 'package:bb_mobile/core/address/data/models/address_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';

abstract class AddressDatasource {
  Future<AddressModel> getNewAddress({
    required WalletModel wallet,
  });
  Future<AddressModel> getLastUnusedAddress({
    required WalletModel wallet,
  });
  Future<AddressModel> getAddressByIndex(
    int index, {
    required WalletModel wallet,
  });
  Future<List<AddressModel>> getReceiveAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  });
  Future<List<AddressModel>> getChangeAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  });
  Future<bool> isAddressUsed(
    String address, {
    required WalletModel wallet,
  });
  Future<BigInt> getAddressBalanceSat(
    String address, {
    required WalletModel wallet,
  });
}
