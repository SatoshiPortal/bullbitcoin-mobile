import 'package:bb_mobile/core/domain/entities/address.dart';
import 'package:bb_mobile/core/domain/entities/balance.dart';
import 'package:bb_mobile/core/domain/entities/payjoin.dart';
import 'package:bb_mobile/core/domain/entities/seed.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';

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
  Future<List<Wallet>> getWallets({Environment? environment});
  Future<void> sync({required String walletId});
  Future<void> syncAll();
  Future<Balance> getBalance({required String walletId});
  Future<Address> getAddressByIndex({
    required String walletId,
    required int index,
  });
  Future<Address> getLastUnusedAddress({required String walletId});
  Future<Address> getNewAddress({required String walletId});
  Future<Seed> getSeed({required String walletId});
  Future<Payjoin> receivePayjoin({required String walletId});
  Future<Payjoin> sendPayjoin({required String walletId});
}
