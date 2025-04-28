import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';

abstract class WalletDatasource {
  Future<WalletAddressModel> getNewAddress({
    required WalletModel wallet,
  });
  Future<WalletAddressModel> getLastUnusedAddress({
    required WalletModel wallet,
    bool isChange = false,
  });
  Future<WalletAddressModel> getAddressByIndex(
    int index, {
    required WalletModel wallet,
  });
  Future<List<WalletAddressModel>> getReceiveAddresses({
    required WalletModel wallet,
    required int limit,
    required int offset,
  });
  Future<List<WalletAddressModel>> getChangeAddresses({
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
  Future<List<WalletUtxoModel>> getUtxos({
    required WalletModel wallet,
  });
}
