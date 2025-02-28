import 'package:bb_mobile/core/data/models/address_model.dart';
import 'package:bb_mobile/core/data/models/balance_model.dart';

abstract class WalletDataSource {
  Future<void> sync();
  Future<BalanceModel> getBalance();
  Future<AddressModel> getAddressByIndex(int index);
  Future<AddressModel> getLastUnusedAddress();
  Future<AddressModel> getNewAddress();
  Future<bool> isAddressUsed(String address);
  Future<BigInt> getAddressBalance(String address);
}
