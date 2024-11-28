import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:path_provider/path_provider.dart';

class WalletsStorageRepository {
  WalletsStorageRepository({required HiveStorage hiveStorage})
      : _hiveStorage = hiveStorage;

  final HiveStorage _hiveStorage;

  Future<Err?> sortWallets() async {
    try {
      final (walletIds, err) = await _hiveStorage.getValue(StorageKeys.wallets);
      if (err != null) return err;
      final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

      final List<Wallet> wallets = [];

      for (final id in walletIdsJson) {
        final (wallet, err) = await readWallet(walletHashId: id as String);
        if (err != null) continue;
        wallets.add(wallet!);
      }

      final hasMainWallet = wallets.any((element) => element.mainWallet);
      if (!hasMainWallet) return Err('No Main Wallet Found');

      final mainWalletIdx = wallets.indexWhere(
        (w) => !w.isTestnet() && w.isSecure(),
      );
      final tempMain = wallets[mainWalletIdx];
      wallets.removeAt(mainWalletIdx);

      final liqMainnetIdx = wallets.indexWhere(
        (w) => !w.isTestnet() && w.isInstant(),
      );
      final tempLiq = wallets[liqMainnetIdx];
      wallets.removeAt(liqMainnetIdx);

      wallets.insert(0, tempLiq);
      wallets.insert(1, tempMain);

      // BEGIN: Testnet wallet sorting
      final mainTestWalletIdx = wallets.indexWhere(
        (w) => w.isTestnet() && w.isSecure(),
      );

      if (mainTestWalletIdx != -1) {
        final tempMainTest = wallets[mainTestWalletIdx];
        wallets.removeAt(mainTestWalletIdx);

        final liqTestMainnetIdx = wallets.indexWhere(
          (w) => w.isTestnet() && w.isInstant(),
        );

        if (liqTestMainnetIdx != -1) {
          final tempLiqTest = wallets[liqTestMainnetIdx];
          wallets.removeAt(liqTestMainnetIdx);
          wallets.insert(2, tempLiqTest);
        }

        wallets.insert(3, tempMainTest);
      }
      // END: Testnet wallet sorting

      final List<String> ids = [];
      for (final w in wallets) {
        ids.add(w.id);
      }

      final idsJsn = jsonEncode({
        'wallets': [...ids],
      });
      final _ = await _hiveStorage.saveValue(
        key: StorageKeys.wallets,
        value: idsJsn,
      );
      return null;
    } catch (e) {
      return Err(
        e.toString(),
        expected: true,
      );
    }
  }

  Future<Err?> newWallet(
    Wallet wallet,
  ) async {
    try {
      final walletIdIndex = wallet.getWalletStorageString();
      final (walletIds, err) = await _hiveStorage.getValue(StorageKeys.wallets);
      if (err != null) {
        // no wallets exist make this the first
        final jsn = jsonEncode({
          'wallets': [walletIdIndex],
        });
        final _ = await _hiveStorage.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
      } else {
        final walletIdsJson =
            jsonDecode(walletIds!)['wallets'] as List<dynamic>;

        final List<String> walletHashIds = [];
        for (final id in walletIdsJson) {
          if (id == walletIdIndex) {
            return Err('Wallet Exists');
          } else {
            walletHashIds.add(id as String);
          }
        }

        walletHashIds.add(walletIdIndex);

        final jsn = jsonEncode({
          'wallets': [...walletHashIds],
        });
        final _ = await _hiveStorage.saveValue(
          key: StorageKeys.wallets,
          value: jsn,
        );
      }

      await _hiveStorage.saveValue(
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
  }) async {
    try {
      final (jsn, err) = await _hiveStorage.getValue(walletHashId);
      if (err != null) throw err;
      final obj = jsonDecode(jsn!) as Map<String, dynamic>;
      final wallet = Wallet.fromJson(obj);
      return (wallet, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          expected: e.toString() == 'No Wallet with index $walletHashId',
        )
      );
    }
  }

  Future<(List<Wallet>?, Err?)> readAllWallets() async {
    try {
      final (walletIds, err) = await _hiveStorage
          .getValue(StorageKeys.wallets); // returns wallet indexes
      if (err != null) throw err;

      final walletIdsJson = jsonDecode(walletIds!)['wallets'] as List<dynamic>;

      final List<Wallet> wallets = [];
      for (final w in walletIdsJson) {
        try {
          final (wallet, err) = await readWallet(walletHashId: w as String);
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

  Future<Err?> updateWallet(Wallet wallet) async {
    try {
      final (_, err) = await readWallet(
        walletHashId: wallet.getWalletStorageString(),
      );
      if (err != null) throw err;
      // improve this error
      // does not exist to update, use create

      final _ = await _hiveStorage.saveValue(
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
  }) async {
    try {
      final (walletIds, err) = await _hiveStorage.getValue(StorageKeys.wallets);
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
      final _ = await _hiveStorage.saveValue(
        key: StorageKeys.wallets,
        value: jsn,
      );
      await _hiveStorage.deleteValue(walletHashId);
      return null;
    } on Exception catch (e) {
      return Err(
        e.message,
        title: 'Error occurred while deleting wallet',
        solution: 'Please try again.',
      );
    }
  }

  Future<Err?> deleteWalletFile(String walletHashId) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final Directory dbDirect = Directory(appDocDir.path + '/$walletHashId');
    if (dbDirect.existsSync()) {
      await dbDirect.delete(recursive: true);
    }
    return null;
  }
}
