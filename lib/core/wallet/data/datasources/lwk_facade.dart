import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_dir_guard.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

/// Every LWK operation goes through [withPublicWallet]/[withPrivateWallet]:
/// two wollets on the same on-disk cache directory race each other and
/// `apply_update` throws `UpdateOnDifferentStatus`, so access is serialized
/// per cache directory via [LwkDirGuard].
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

  static Future<T> _guarded<T>(
    String walletIdHex,
    Future<T> Function(String dbPath) action,
  ) async {
    final dbPath = await _getDbPath(walletIdHex);
    return LwkDirGuard.run(dbPath, () => action(dbPath));
  }

  /// Opens the watch-only wollet for [walletModel] and runs [action] with
  /// exclusive access to its cache directory.
  static Future<T> withPublicWallet<T>(
    WalletModel walletModel,
    Future<T> Function(lwk.Wallet wallet) action,
  ) async {
    if (walletModel is! PublicLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }
    // Errors (including LwkError) propagate untouched: callers map them and
    // detect recoverable ones like UpdateOnDifferentStatus.
    return _guarded(walletModel.hexId, (dbPath) async {
      final network = walletModel.isTestnet
          ? lwk.LiquidNetwork.testnet
          : lwk.LiquidNetwork.mainnet;
      final descriptor = lwk.Descriptor(
        ctDescriptor: walletModel.combinedCtDescriptor,
      );
      final wallet = await lwk.Wallet.init(
        network: network,
        dbpath: dbPath,
        descriptor: descriptor,
      );
      return action(wallet);
    });
  }

  /// Opens the signing wollet for [walletModel] and runs [action] with
  /// exclusive access to its cache directory.
  static Future<T> withPrivateWallet<T>(
    WalletModel walletModel,
    Future<T> Function(lwk.Wallet wallet) action,
  ) async {
    if (walletModel is! PrivateLwkWalletModel) {
      throw Exception('Wallet is not an LWK wallet');
    }
    return _guarded(walletModel.hexId, (dbPath) async {
      final network = walletModel.isTestnet
          ? lwk.LiquidNetwork.testnet
          : lwk.LiquidNetwork.mainnet;
      final descriptor = await lwk.Descriptor.newConfidential(
        mnemonic: walletModel.mnemonic,
        network: network,
      );
      final wallet = await lwk.Wallet.init(
        network: network,
        dbpath: dbPath,
        descriptor: descriptor,
      );
      return action(wallet);
    });
  }

  static Future<void> delete(WalletModel walletModel) async {
    await _guarded(walletModel.hexId, (dbPath) async {
      try {
        final dbFile = File(dbPath);

        if (!await dbFile.exists()) throw WalletError.notFound(walletModel.id);
        log.fine('Found LwkDb');
        await dbFile.delete(recursive: true);
      } catch (e) {
        log.warning('Failed to delete LwkDb', error: e);
        rethrow;
      }
    });
  }
}
