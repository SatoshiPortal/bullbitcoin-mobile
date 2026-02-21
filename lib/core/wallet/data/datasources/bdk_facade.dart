import 'dart:io';

import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class BdkFacade {
  // Standard lookahead value for address discovery
  static const int _lookahead = 25;

  static Future<bdk.Wallet> createWallet(WalletModel walletModel) {
    if (walletModel is PublicBdkWalletModel) {
      return createPublicWallet(walletModel);
    } else if (walletModel is PrivateBdkWalletModel) {
      return createPrivateWallet(walletModel);
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

    final external = bdk.Descriptor(walletModel.externalDescriptor, network);
    final internal = bdk.Descriptor(walletModel.internalDescriptor, network);

    // Get the database path based on the wallet's id for uniqueness and in hex
    // to ensure it's a valid filename
    final dbPath = await _getDbPath(walletModel.hexId);
    final dbFile = File(dbPath);

    try {
      final dbPersister = bdk.Persister.newSqlite(dbPath);

      // Use load if database (wallet) exists, otherwise create new
      final wallet = await dbFile.exists()
          ? bdk.Wallet.load(external, internal, dbPersister, _lookahead)
          : bdk.Wallet(external, internal, network, dbPersister, _lookahead);

      return wallet;
    } catch (e) {
      // If there's any error (corrupted db, etc.), delete and recreate
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      final dbPersister = bdk.Persister.newSqlite(dbPath);
      return bdk.Wallet(external, internal, network, dbPersister, _lookahead);
    }
  }

  static Future<bdk.Wallet> createPrivateWallet(WalletModel walletModel) async {
    if (walletModel is! PrivateBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PrivateBdkWalletModel');
    }

    final network = walletModel.isTestnet
        ? bdk.Network.testnet
        : bdk.Network.bitcoin;

    final bdkMnemonic = bdk.Mnemonic.fromString(walletModel.mnemonic);
    final secretKey = bdk.DescriptorSecretKey(
      network,
      bdkMnemonic,
      walletModel.passphrase,
    );

    bdk.Descriptor? external;
    bdk.Descriptor? internal;

    switch (walletModel.scriptType) {
      case ScriptType.bip84:
        external = bdk.Descriptor.newBip84(
          secretKey,
          bdk.KeychainKind.external_,
          network,
        );
        internal = bdk.Descriptor.newBip84(
          secretKey,
          bdk.KeychainKind.internal,
          network,
        );
      case ScriptType.bip49:
        external = bdk.Descriptor.newBip49(
          secretKey,
          bdk.KeychainKind.external_,
          network,
        );
        internal = bdk.Descriptor.newBip49(
          secretKey,
          bdk.KeychainKind.internal,
          network,
        );
      case ScriptType.bip44:
        external = bdk.Descriptor.newBip44(
          secretKey,
          bdk.KeychainKind.external_,
          network,
        );
        internal = bdk.Descriptor.newBip44(
          secretKey,
          bdk.KeychainKind.internal,
          network,
        );
    }

    // Get the database path
    final dbPath = await _getDbPath(walletModel.hexId);
    final dbFile = File(dbPath);

    try {
      final dbPersister = bdk.Persister.newSqlite(dbPath);

      // Use load if database exists, otherwise create new
      final wallet = await dbFile.exists()
          ? bdk.Wallet.load(external, internal, dbPersister, _lookahead)
          : bdk.Wallet(external, internal, network, dbPersister, _lookahead);

      return wallet;
    } catch (e) {
      // If there's any error (corrupted db, etc.), delete and recreate
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      final dbPersister = bdk.Persister.newSqlite(dbPath);
      return bdk.Wallet(external, internal, network, dbPersister, _lookahead);
    }
  }

  /// Persists wallet changes to the database
  static Future<void> saveWallet(
    bdk.Wallet bdkWallet,
    String walletIdHex,
  ) async {
    final dbPath = await _getDbPath(walletIdHex);
    final persister = bdk.Persister.newSqlite(dbPath);
    bdkWallet.persist(persister);
  }

  static Future<String> _getDbPath(String walletIdHex) async {
    final dir = await getApplicationDocumentsDirectory();
    // Add since bdk_dart might not migrate old bdk_flutter db we suffix the db name with `_bdk_dart` to avoid conflicts
    return '${dir.path}/${'${walletIdHex}_bdk_dart'}';
  }

  static Future<void> delete(WalletModel walletModel) async {
    final dbPath = await _getDbPath(walletModel.hexId);
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) WalletError.notFound(walletModel.id);

    await dbFile.delete();
  }

  static Future<void> sync(
    WalletModel wallet,
    ElectrumServerModel electrumServer,
    ElectrumSettingsModel electrumSettings,
  ) async {
    final blockchain = bdk.ElectrumClient(
      electrumServer.url,
      // Only set the socks5 if it's not empty,
      //  otherwise bdk will throw an error
      // TODO: this was in bdk_flutter, check if it's still needed in bdk_dart
      electrumSettings.socks5?.isNotEmpty == true
          ? electrumSettings.socks5
          : null,
    );

    final bdkWallet = await BdkFacade.createWallet(wallet);
    final scanRequest = bdkWallet.startFullScan().build();
    final update = blockchain.fullScan(
      scanRequest,
      electrumSettings.stopGap,
      20, // TODO: Should we make `batchSize` configurable in electrumSettings as well?
      true, // TODO: Should we make `fetchPrevTxouts` configurable in electrumSettings as well?
    );
    bdkWallet.applyUpdate(update);
  }
}
