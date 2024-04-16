// ignore_for_file: avoid_print

import 'package:bb_arch/_pkg/seed/models/seed.dart';
import 'package:bb_arch/_pkg/storage/hive.dart';
import 'package:bb_arch/_pkg/wallet/bitcoin_wallet_helper.dart';
import 'package:bb_arch/_pkg/wallet/models/wallet.dart';
import 'package:isar/isar.dart';

class WalletRepository {
  WalletRepository({required this.storage, required this.isar}) {
    initOnAppStart();
  }

  HiveStorage storage;
  Isar isar;

  Future<void> initOnAppStart() async {
    print('Init on app start');
    try {
      final (_, err) = await storage.getValue('appInitDone');
      if (err?.message == 'No Key') {
        await setupWallets();
        await storage.saveValue(key: 'appInitDone', value: 'yes');
      }
    } catch (e) {
      return;
    }
  }

  Future<(List<Wallet>?, dynamic)> loadWallets() async {
    try {
      final wallets = await isar.wallets.where().findAll();
      return (wallets, null);
    } catch (e) {
      return (null, e);
    }
  }

  Future<void> persistWallet(Wallet wallet) async {
    await isar.writeTxn(() async {
      await isar.wallets.putByIndex("id", wallet);
    });
  }

  Future<void> setupWallets() async {}

  Future<(List<Wallet>?, dynamic)> deriveWalletsFromSeed(Seed seed) async {
    final ws = await BitcoinWalletHelper.initializeAllWallets(seed);
    return (ws, null);
  }
}
