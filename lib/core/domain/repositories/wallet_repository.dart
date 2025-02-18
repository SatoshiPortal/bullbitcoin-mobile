import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/entities/balance.dart';

abstract class WalletRepository {
  String get id;
  Future<Balance> getBalance();
  Future<Address> getAddressByIndex(int index);
  Future<Address> getLastUnusedAddress();
}
