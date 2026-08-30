import 'dart:io';

import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:path_provider/path_provider.dart';

class BdkFacade {
  // Standard lookahead value for address discovery
  static const int _lookahead = 25;
  static final Expando<_WalletPersistence> _persisters = Expando(
    'bdk wallet persister',
  );
  static final Map<String, int> _databaseGenerations = {};

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
    final existed = await dbFile.exists();

    final dbPersister = bdk.Persister.newSqlite(path: dbPath);
    try {
      // Use load if database (wallet) exists, otherwise create new
      final wallet = existed
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

      // The Rust wallet keeps using the persister after construction. Retain
      // the Dart owner for exactly as long as the returned wallet stays alive.
      _persisters[wallet] = _WalletPersistence(
        persister: dbPersister,
        databasePath: dbPath,
        generation: _databaseGenerations[dbPath] ?? 0,
      );
      return wallet;
    } catch (_) {
      dbPersister.dispose();
      rethrow;
    }
  }

  static Future<bdk.Wallet> createPrivateWallet(WalletModel walletModel) async {
    if (walletModel is! PrivateBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PrivateBdkWalletModel');
    }

    final network = walletModel.isTestnet
        ? bdk.Network.testnet
        : bdk.Network.bitcoin;
    final networkKind = walletModel.isTestnet
        ? bdk.NetworkKind.test
        : bdk.NetworkKind.main;

    final bdkMnemonic = bdk.Mnemonic.fromString(mnemonic: walletModel.mnemonic);
    final secretKey = bdk.DescriptorSecretKey(
      networkKind: networkKind,
      mnemonic: bdkMnemonic,
      password: walletModel.passphrase,
    );

    bdk.Descriptor? external;
    bdk.Descriptor? internal;

    switch (walletModel.scriptType) {
      case ScriptType.bip84:
        external = bdk.Descriptor.newBip84(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.external_,
          networkKind: networkKind,
        );
        internal = bdk.Descriptor.newBip84(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.internal,
          networkKind: networkKind,
        );
      case ScriptType.bip49:
        external = bdk.Descriptor.newBip49(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.external_,
          networkKind: networkKind,
        );
        internal = bdk.Descriptor.newBip49(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.internal,
          networkKind: networkKind,
        );
      case ScriptType.bip44:
        external = bdk.Descriptor.newBip44(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.external_,
          networkKind: networkKind,
        );
        internal = bdk.Descriptor.newBip44(
          secretKey: secretKey,
          keychainKind: bdk.KeychainKind.internal,
          networkKind: networkKind,
        );
    }

    // Get the database path
    final dbPath = await _getDbPath(walletModel.hexId);
    final dbFile = File(dbPath);
    final existed = await dbFile.exists();

    final dbPersister = bdk.Persister.newSqlite(path: dbPath);
    try {
      // Use load if database exists, otherwise create new
      final wallet = existed
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

      _persisters[wallet] = _WalletPersistence(
        persister: dbPersister,
        databasePath: dbPath,
        generation: _databaseGenerations[dbPath] ?? 0,
      );
      return wallet;
    } catch (_) {
      dbPersister.dispose();
      rethrow;
    }
  }

  /// Persists wallet changes to the database
  static Future<void> saveWallet(
    bdk.Wallet bdkWallet,
    String walletIdHex,
  ) async {
    final ownedPersister = _persisters[bdkWallet];
    if (ownedPersister != null) {
      if ((_databaseGenerations[ownedPersister.databasePath] ?? 0) !=
          ownedPersister.generation) {
        throw StateError('BDK wallet persistence is no longer active');
      }
      bdkWallet.persist(persister: ownedPersister.persister);
      return;
    }

    final dbPath = await _getDbPath(walletIdHex);
    final persister = bdk.Persister.newSqlite(path: dbPath);
    try {
      bdkWallet.persist(persister: persister);
    } finally {
      persister.dispose();
    }
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
    _databaseGenerations.update(
      dbPath,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }
}

final class _WalletPersistence {
  final bdk.Persister persister;
  final String databasePath;
  final int generation;

  const _WalletPersistence({
    required this.persister,
    required this.databasePath,
    required this.generation,
  });
}
