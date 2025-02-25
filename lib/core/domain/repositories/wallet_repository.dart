import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/entities/balance.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';

abstract class WalletRepository {
  String get id;
  Network get network;
  Future<Balance> getBalance();
  Future<Address> getAddressByIndex(int index);
  Future<Address> getLastUnusedAddress();
  Future<Address> getNewAddress();
}
