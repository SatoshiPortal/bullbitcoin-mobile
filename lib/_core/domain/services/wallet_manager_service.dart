import 'package:bb_mobile/_core/domain/entities/address.dart';
import 'package:bb_mobile/_core/domain/entities/balance.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';

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
  Future<List<Wallet>> getAllWallets({Environment? environment});
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
}
