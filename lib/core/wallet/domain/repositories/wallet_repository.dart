import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/entity/balance.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:boltz/boltz.dart';

abstract class WalletRepository {
  // Wallet repo
  Future<void> sync({required ElectrumServer electrumServer});
  Future<Balance> getBalance();
  Future<List<Utxo>> listUnspent();
  // Future<List<Address>> listAddresses();
  // transaction repo
  Future<Address> getAddressByIndex(int index);
  Future<Address> getLastUnusedAddress();
  Future<Address>
      getNewAddress(); // create receive transaction param(index/lastUnused)
  Future<bool> isAddressUsed(String address);
  Future<BigInt> getAddressBalanceSat(String address);
  Future<List<BaseWalletTransaction>> getTransactions(String walletId);
  // labels: label datasource + repo (import/export bip329/label lookup)
}
