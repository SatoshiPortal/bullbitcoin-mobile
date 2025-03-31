import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/entity/address.dart';
import 'package:bb_mobile/core/wallet/domain/entity/balance.dart';
import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/tx_input.dart';
import 'package:bb_mobile/core/wallet/domain/entity/utxo.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';

abstract class WalletManagerService {
  Future<bool> doDefaultWalletsExist({required Environment environment});
  Future<void> initExistingWallets();
  Future<Wallet> createWallet({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label,
    bool isDefault,
  });
  Future<Wallet> importWatchOnlyWallet({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
  });
  Future<Wallet?> getWallet(String id);
  Future<List<Wallet>> getWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
  });
  Future<Wallet> sync({required String walletId});
  Future<List<Wallet>> syncAll({Environment? environment});
  Future<Balance> getBalance({required String walletId});
  Future<Address> getAddressByIndex({
    required String walletId,
    required int index,
  });
  Future<List<Address>> getUsedReceiveAddresses({
    required String walletId,
    int? limit,
    int? offset,
  });
  Future<Address> getLastUnusedAddress({required String walletId});
  Future<Address> getNewAddress({required String walletId});
  Future<List<Utxo>> getUnspentUtxos({required String walletId});
  Future<bool> isOwnedByWallet({
    required String walletId,
    required Uint8List scriptBytes,
  });
  Future<Transaction> buildUnsigned({
    required String walletId,
    required String address,
    BigInt? amountSat,
    BigInt? absoluteFeeSat,
    double? feeRateSatPerVb,
    List<TxInput>? unspendableInputs,
    bool? drain,
    List<TxInput>? selectableInputs,
    bool replaceByFees,
  });
  Future<Transaction> sign({required String walletId, required Transaction tx});
  Future<List<BaseWalletTransaction>> getBaseTransactions({
    required String walletId,
  });
}
