import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:path_provider/path_provider.dart';

class WalletRepository {
  Future<Err?> newWallet({
    required Wallet wallet,
    required HiveStorage hiveStore,
  }) async {
    try {
      final walletIdIndex = wallet.getWalletStorageString();
      final (walletIds, err) = await hiveStore.getValue(StorageKeys.wallets);
      if (err != null) {
        // no wallets exist make this the first
        final jsn = jsonEncode({
          'wallets': [walletIdIndex],
        });
        final _ = await hiveStore.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
      } else {
        final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

        final List<String> walletHashIds = [];
        for (final id in walletIdsJson) {
          if (id == walletIdIndex)
            return Err('Wallet Exists');
          else
            walletHashIds.add(id as String);
        }

        walletHashIds.add(walletIdIndex);

        final jsn = jsonEncode({
          'wallets': [...walletHashIds],
        });
        final _ = await hiveStore.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
      }

      await hiveStore.saveValue(
        key: walletIdIndex,
        value: jsonEncode(wallet),
      );
      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while saving wallet',
        solution: 'Please try again.',
      );
    }
  }

  Future<(Wallet?, Err?)> readWallet({
    required String walletHashId,
    required HiveStorage hiveStore,
  }) async {
    try {
      final (jsn, err) = await hiveStore.getValue(walletHashId);
      if (err != null) throw err;
      // log(jsn!);
      final obj = jsonDecode(jsn!) as Map<String, dynamic>;
      final wallet = Wallet.fromJson(obj);
      return (wallet, null);
    } catch (e) {
      return (
        null,
        Err(e.toString(), expected: e.toString() == 'No Wallet with index $walletHashId')
      );
    }
  }

  Future<(List<Wallet>?, Err?)> readAllWallets({
    required HiveStorage hiveStore,
  }) async {
    try {
      final (walletIds, err) =
          await hiveStore.getValue(StorageKeys.wallets); // returns wallet indexes
      if (err != null) throw err;

      final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

      final List<Wallet> wallets = [];
      for (final w in walletIdsJson) {
        try {
          final (wallet, err) = await readWallet(
            walletHashId: w as String,
            hiveStore: hiveStore,
          );
          if (err != null) continue;
          wallets.add(wallet!);
        } catch (e) {
          print(e);
        }
      }

      return (wallets, null);
    } catch (e) {
      return (null, Err(e.toString(), expected: e.toString() == 'No Key'));
    }
  }

  Future<Err?> updateWallet({
    required Wallet wallet,
    required HiveStorage hiveStore,
  }) async {
    try {
      final (_, err) = await readWallet(
        walletHashId: wallet.getWalletStorageString(),
        hiveStore: hiveStore,
      );
      if (err != null) throw err;
      // improve this error
      // does not exist to update, use create

      final _ = await hiveStore.saveValue(
        key: wallet.getWalletStorageString(),
        value: jsonEncode(
          wallet,
        ),
      );
      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while updating wallet',
        solution: 'Please try again.',
      );
    }
  }

  Future<Err?> deleteWallet({
    required String walletHashId,
    required HiveStorage storage,
  }) async {
    try {
      final (walletIds, err) = await storage.getValue(StorageKeys.wallets);
      if (err != null) throw err;

      final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

      final List<String> walletHashIds = [];
      for (final id in walletIdsJson) {
        walletHashIds.add(id as String);
      }

      walletHashIds.remove(walletHashId);

      final jsn = jsonEncode({
        'wallets': [...walletHashIds],
      });

      final _ = await storage.saveValue(
        key: StorageKeys.wallets,
        value: jsn,
      );

      await storage.deleteValue(walletHashId);
      final appDocDir = await getApplicationDocumentsDirectory();
      final File dbDir = File(appDocDir.path + '/$walletHashId');
      // final File dbDirSigner = File(appDocDir.path + '/${walletHashId}_signer');

      await dbDir.delete();
      // await dbDirSigner.delete();
      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while deleting wallet',
        solution: 'Please try again.',
      );
    }
  }
}
