import 'package:bb_mobile/features/wallet/domain/entities/address.dart';
import 'package:bb_mobile/features/wallet/domain/entities/balance.dart';

abstract class WalletRepository {
  String get id;
  Future<Balance> getBalance();
  Future<Address> getAddressByIndex(int index);
  Future<Address> getLastUnusedAddress();
}
