import 'package:bb_mobile/_core/domain/entities/address.dart';
import 'package:bb_mobile/_core/domain/entities/balance.dart';
import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';

abstract class WalletManagerRepository {
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
  Future<List<Wallet>> getAllWallets({Environment? environment});
  Future<void> sync({required String walletId});
  Future<void> syncAll({Environment? environment});
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
  Future<Seed> getSeed({required String walletId});
  Future<Payjoin> receivePayjoin({
    required String walletId,
    String? address,
    int? expireAfterSec,
  });
  Future<Payjoin> sendPayjoin({
    required String walletId,
    required String bip21,
    BigInt? amountSat,
    required double networkFeesSatPerVb,
  });
}
