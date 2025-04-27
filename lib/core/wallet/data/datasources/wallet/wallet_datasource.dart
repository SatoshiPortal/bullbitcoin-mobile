import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/wallet/data/models/address_model.dart';
import 'package:bb_mobile/core/wallet/data/models/utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';

abstract class WalletDatasource {
  Future<AddressModel> getNewAddress({
    required WalletModel wallet,
  });
  Future<AddressModel> getLastUnusedAddress({
    required WalletModel wallet,
    bool isChange = false,
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
  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  });
  Future<void> sync({
    required WalletModel wallet,
    required ElectrumServerModel electrumServer,
  });
  Future<List<UtxoModel>> getUtxos({
    required WalletModel wallet,
  });
}
