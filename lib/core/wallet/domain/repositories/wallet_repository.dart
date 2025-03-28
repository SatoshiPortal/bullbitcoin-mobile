

import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/entity/balance.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';

abstract class WalletRepository {
  Future<void> sync({required ElectrumServer electrumServer});
  Future<Balance> getBalance();
  Future<Address> getAddressByIndex(int index);
  Future<Address> getLastUnusedAddress();
  Future<Address> getNewAddress();
  Future<bool> isAddressUsed(String address);
  Future<BigInt> getAddressBalanceSat(String address);
  Future<List<Utxo>> listUnspent();
}
