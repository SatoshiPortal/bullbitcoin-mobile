import 'lwk_wallet_session.dart';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:wallet/wallet.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LwkFacade {
  static Future<String> _getDbPath(String walletIdHex) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$walletIdHex';
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }

  static Future<void> delete(WalletModel walletModel) async {
    try {
      final dbPath = await _getDbPath(walletModel.hexId);
      // dbPath is the base dir lwk_wollet's with_legacy_fs_store builds on
      // (dbPath/<network>/enc_cache/<descriptor hash>/...), not a file —
      // File(dbPath).exists() always returns false for it, so the
      // UpdateOnDifferentStatus heal (see lwk_wallet_datasource.dart) that
      // calls this to wipe the cache and retry always threw
      // WalletError.notFound instead of actually deleting anything.
      final dbDir = Directory(dbPath);

      if (!await dbDir.exists()) throw WalletError.notFound(walletModel.id);
      log.fine('Found LwkDb');
      await dbDir.delete(recursive: true);
    } catch (e) {
      log.warning('Failed to delete LwkDb', error: e);
      rethrow;
    }
  }

  static Future<lwk.Wallet> createPublicWallet(WalletModel walletModel) async {
    try {
      if (walletModel is! PublicLwkWalletModel) {
        throw Exception('Wallet is not an LWK wallet');
      }
      final network = walletModel.isTestnet
          ? lwk.LiquidNetwork.testnet
          : lwk.LiquidNetwork.mainnet;
      final descriptor = lwk.Descriptor(
        ctDescriptor: walletModel.combinedCtDescriptor,
      );
      final dbPath = await _getDbPath(walletModel.hexId);
      final wallet = await LwkWalletSession.openNativeWallet(
        network: network,
        databasePath: dbPath,
        descriptor: descriptor,
      );
      return wallet;
    } catch (e) {
      if (e is lwk.LwkError) {
        throw e.msg;
      } else {
        rethrow;
      }
    }
  }
}
