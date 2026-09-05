import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class BdkFacade {
  // Standard lookahead value for address discovery
  static const int _lookahead = 25;
  static final Expando<_WalletPersistence> _persisters = Expando(
    'bdk wallet persister',
  );
  static final Map<String, int> _databaseGenerations = {};

  static Future<bdk.Wallet> _createWallet(WalletModel walletModel) {
    if (walletModel is PublicBdkWalletModel) {
      return _createPublicWallet(walletModel);
    } else if (walletModel is PrivateBdkWalletModel) {
      return _createPrivateWallet(walletModel);
    } else {
      throw ArgumentError('Unsupported wallet model type');
    }
  }

  /// Reconstructs a wallet for one operation and owns its persistence pair.
  ///
  /// The persister must outlive the wallet operation, so disposal is deliberately
  /// ordered wallet first and persister second.
  static Future<T> withWallet<T>(
    WalletModel walletModel,
    FutureOr<T> Function(bdk.Wallet wallet) operation,
  ) async {
    final wallet = await _createWallet(walletModel);
    final persistence = _persisters[wallet];
    if (persistence == null) {
      wallet.dispose();
      throw StateError('BDK wallet persistence owner is missing');
    }
    return runWithDisposal(
      action: () => operation(wallet),
      disposeWallet: wallet.dispose,
      disposePersister: persistence.persister.dispose,
    );
  }

  @visibleForTesting
  static Future<T> runWithDisposal<T>({
    required FutureOr<T> Function() action,
    required void Function() disposeWallet,
    required void Function() disposePersister,
  }) async {
    try {
      return await action();
    } finally {
      try {
        disposeWallet();
      } finally {
        disposePersister();
      }
    }
  }

  static Future<bdk.Wallet> _createPublicWallet(WalletModel walletModel) async {
    if (walletModel is! PublicBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PublicBdkWalletModel');
    }

    final network = walletModel.isTestnet
        ? bdk.Network.testnet
        : bdk.Network.bitcoin;
    final networkKind = walletModel.isTestnet
        ? bdk.NetworkKind.test
        : bdk.NetworkKind.main;

    bdk.Descriptor? external;
    bdk.Descriptor? internal;
    try {
      external = bdk.Descriptor(
        descriptor: walletModel.externalDescriptor,
        networkKind: networkKind,
      );
      internal = bdk.Descriptor(
        descriptor: walletModel.internalDescriptor,
        networkKind: networkKind,
      );
      bdk.Persister? dbPersister;
      try {
        final dbPath = await _getDbPath(walletModel.hexId);
        final dbFile = File(dbPath);
        final existed = await dbFile.exists();
        dbPersister = bdk.Persister.newSqlite(path: dbPath);
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
        dbPersister?.dispose();
        rethrow;
      }
    } finally {
      _disposeDescriptor(internal);
      _disposeDescriptor(external);
    }
  }

  static Future<bdk.Wallet> _createPrivateWallet(
    WalletModel walletModel,
  ) async {
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
    try {
      final secretKey = bdk.DescriptorSecretKey(
        networkKind: networkKind,
        mnemonic: bdkMnemonic,
        password: walletModel.passphrase,
      );
      try {
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

        bdk.Persister? dbPersister;
        try {
          final dbPath = await _getDbPath(walletModel.hexId);
          final dbFile = File(dbPath);
          final existed = await dbFile.exists();
          dbPersister = bdk.Persister.newSqlite(path: dbPath);
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
          dbPersister?.dispose();
          rethrow;
        } finally {
          _disposeDescriptor(internal);
          _disposeDescriptor(external);
        }
      } finally {
        secretKey.dispose();
      }
    } finally {
      bdkMnemonic.dispose();
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

void _disposeDescriptor(bdk.Descriptor? descriptor) => descriptor?.dispose();

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
