import 'dart:io';

import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:lwk/lwk.dart' as lwk;
import 'package:path_provider/path_provider.dart';

class LwkFacade {
  static Future<String> _getDbPath(String dbName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$dbName';
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
      final dbPath = await _getDbPath(walletModel.dbName);
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) WalletError.notFound(walletModel.id);

      await dbFile.delete();
    } catch (e) {
      rethrow;
    }
  }

  static Future<lwk.Wallet> createPublicWallet(WalletModel walletModel) async {
    try {
      if (walletModel is! PublicLwkWalletModel) {
        throw Exception('Wallet is not an LWK wallet');
      }
      final network = walletModel.isTestnet
          ? lwk.Network.testnet
          : lwk.Network.mainnet;
      final descriptor = lwk.Descriptor(
        ctDescriptor: walletModel.combinedCtDescriptor,
      );
      final dbPath = await _getDbPath(walletModel.dbName);
      final wallet = await lwk.Wallet.init(
        network: network,
        dbpath: dbPath,
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

  static Future<lwk.Wallet> createPrivateWallet(WalletModel walletModel) async {
    try {
      if (walletModel is! PrivateLwkWalletModel) {
        throw Exception('Wallet is not an LWK wallet');
      }
      final network = walletModel.isTestnet
          ? lwk.Network.testnet
          : lwk.Network.mainnet;
      final descriptor = await lwk.Descriptor.newConfidential(
        mnemonic: walletModel.mnemonic,
        network: network,
      );
      final dbPath = await _getDbPath(walletModel.dbName);
      final wallet = await lwk.Wallet.init(
        network: network,
        dbpath: dbPath,
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

  static Future<void> sync(
    WalletModel wallet,
    ElectrumServerModel electrumServer,
    ElectrumSettingsModel electrumSettings,
  ) async {
    final lwkWallet = await LwkFacade.createPublicWallet(wallet);
    await lwkWallet.sync_(
      electrumUrl: electrumServer.url,
      validateDomain: electrumSettings.validateDomain,
    );
  }
}
