import 'dart:io';

import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class BdkFacade {
  // Standard lookahead value for address discovery
  static const int _lookahead = 25;

  static Future<bdk.Wallet> createWallet(WalletModel walletModel) {
    if (walletModel is PublicBdkWalletModel) {
      return createPublicWallet(walletModel);
    } else {
      throw ArgumentError('Unsupported wallet model type');
    }
  }

  static Future<bdk.Wallet> createPublicWallet(WalletModel walletModel) async {
    if (walletModel is! PublicBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PublicBdkWalletModel');
    }

    final network = walletModel.isTestnet
        ? bdk.Network.testnet
        : bdk.Network.bitcoin;
    final networkKind = walletModel.isTestnet
        ? bdk.NetworkKind.test
        : bdk.NetworkKind.main;

    final external = bdk.Descriptor(
      descriptor: walletModel.externalDescriptor,
      networkKind: networkKind,
    );
    final internal = bdk.Descriptor(
      descriptor: walletModel.internalDescriptor,
      networkKind: networkKind,
    );

    // Get the database path based on the wallet's id for uniqueness and in hex
    // to ensure it's a valid filename
    final dbPath = await _getDbPath(walletModel.hexId);
    final dbFile = File(dbPath);

    try {
      final dbPersister = bdk.Persister.newSqlite(path: dbPath);

      // Use load if database (wallet) exists, otherwise create new
      final wallet = await dbFile.exists()
          ? bdk.Wallet.load(
              descriptor: external,
              changeDescriptor: internal,
              persister: dbPersister,
              lookahead: _lookahead,
            )
          : bdk.Wallet(
              descriptor: external,
              changeDescriptor: internal,
              network: network,
              persister: dbPersister,
              lookahead: _lookahead,
            );

      return wallet;
    } catch (e) {
      // If there's any error (corrupted db, etc.), delete and recreate
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      final dbPersister = bdk.Persister.newSqlite(path: dbPath);
      return bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: network,
        persister: dbPersister,
        lookahead: _lookahead,
      );
    }
  }

  /// Persists wallet changes to the database
  static Future<void> saveWallet(
    bdk.Wallet bdkWallet,
    String walletIdHex,
  ) async {
    final dbPath = await _getDbPath(walletIdHex);
    final persister = bdk.Persister.newSqlite(path: dbPath);
    bdkWallet.persist(persister: persister);
  }

  static Future<String> _getDbPath(String walletIdHex) async {
    final dir = await getApplicationDocumentsDirectory();
    // Add since bdk_dart might not migrate old bdk_flutter db we suffix the db name with `_bdk_dart` to avoid conflicts
    return '${dir.path}/${'${walletIdHex}_bdk_dart'}';
  }

  static Future<void> delete(WalletModel walletModel) async {
    final dbPath = await _getDbPath(walletModel.hexId);
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) throw WalletError.notFound(walletModel.id);

    await dbFile.delete();
  }
}
