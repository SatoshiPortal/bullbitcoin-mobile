import 'package:bb_mobile/_core/domain/entities/address.dart';
import 'package:bb_mobile/_core/domain/entities/balance.dart';
import 'package:bb_mobile/_core/domain/entities/electrum_server.dart';

abstract class WalletRepository {
  Future<void> sync({required ElectrumServer electrumServer});
  Future<Balance> getBalance();
  Future<Address> getAddressByIndex(int index);
  Future<Address> getLastUnusedAddress();
  Future<Address> getNewAddress();
  Future<bool> isAddressUsed(String address);
  Future<BigInt> getAddressBalanceSat(String address);
}
