import 'dart:io';
import '../store_identity.dart';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import '../../domain/public_wallet_descriptor.dart';
import '../../domain/wallet_key.dart';
import '../native_store_paths.dart';
import 'datasources/bdk_wallet_store_datasource.dart';
import 'datasources/lwk_wallet_store_datasource.dart';
import 'datasources/native_store_errors.dart';

/// Internal testing seam. Never export native handles through the public API.
abstract interface class NativeWriteSession {
  Future<int> firstUnusedIndex();
  Future<String> address(int index);
  Future<bool> isUsed(int index, String address);
  Future<void> revealAndPersist(int index);
  void close();
}

abstract interface class NativeWriteSessions {
  Future<NativeWriteSession> open(
    PublicWalletDescriptor descriptor, {
    required bool create,
  });
  Future<void> delete(WalletKey key);
}

/// All opens occur after admission and on this isolate. Never cache a wallet
/// between operations: another isolate may have committed since the last call.
final class SdkWriteSessions implements NativeWriteSessions {
  final String documentsDirectory;

  const SdkWriteSessions(this.documentsDirectory);

  @override
  Future<NativeWriteSession> open(
    PublicWalletDescriptor descriptor, {
    required bool create,
  }) async {
    final path = nativeWalletStoragePath(documentsDirectory, descriptor.key);
    switch (descriptor) {
      case BitcoinWalletDescriptor():
        if (!File(path).existsSync()) {
          if (!create) throw const NativeStoreMissing();
          BdkWalletStoreDatasource.create(path, descriptor);
        }
        return _BitcoinSession(BdkWalletStoreDatasource.load(path, descriptor));
      case LiquidWalletDescriptor():
        if (!create && !Directory(path).existsSync()) {
          throw const NativeStoreMissing();
        }
        final store = await LwkWalletStoreDatasource.open(path, descriptor);
        try {
          final canonical = await store.wallet.descriptor();
          final networkDirectory = switch (descriptor.key.network) {
            LiquidNetwork.mainnet => 'liquid',
            LiquidNetwork.testnet => 'liquid-testnet',
            LiquidNetwork.regtest => 'liquid-regtest',
            _ => throw const NativeNetworkUnsupported(),
          };
          final relative =
              '$networkDirectory/enc_cache/${liquidDirectoryHash(canonical)}';
          if (FileSystemEntity.typeSync(
                '$path/$relative',
                followLinks: false,
              ) !=
              FileSystemEntityType.directory) {
            throw const NativeStoreMissing();
          }
          return _LiquidSession(store, relative);
        } on Object {
          store.close();
          rethrow;
        }
    }
  }

  @override
  Future<void> delete(WalletKey key) async {
    final path = nativeWalletStoragePath(documentsDirectory, key);
    // Readers retain the real store after brief hydration admission. On POSIX,
    // unlink leaves an existing reader's inode alive; later readers get NotFound
    // and never create a store. The writer lock excludes both BDK and Liquid
    // hydration during deletion, without cross-library SQLite lock assumptions.
    switch (key.network) {
      case BitcoinNetwork():
        BdkWalletStoreDatasource.delete(path);
      case LiquidNetwork():
        LwkWalletStoreDatasource.delete(path);
    }
  }
}

final class _BitcoinSession implements NativeWriteSession {
  final BdkWalletStoreDatasource _store;
  Set<int>? _unused;

  _BitcoinSession(this._store);

  bdk.Wallet get _wallet => _store.wallet;

  @override
  Future<int> firstUnusedIndex() async =>
      _wallet.derivationIndex(keychain: bdk.KeychainKind.external_) ?? 0;

  @override
  Future<String> address(int index) async {
    final info = _wallet.peekAddress(
      keychain: bdk.KeychainKind.external_,
      index: index,
    );
    try {
      return info.address.toString();
    } finally {
      info.address.dispose();
    }
  }

  @override
  Future<bool> isUsed(int index, String address) async {
    final last = _wallet.derivationIndex(keychain: bdk.KeychainKind.external_);
    if (last == null || index > last) return false;
    if (_unused == null) {
      final unused = _wallet.listUnusedAddresses(
        keychain: bdk.KeychainKind.external_,
      );
      try {
        _unused = {for (final info in unused) info.index};
      } finally {
        for (final info in unused) {
          info.address.dispose();
        }
      }
    }
    return !(_unused?.contains(index) ?? false);
  }

  @override
  Future<void> revealAndPersist(int index) async {
    final revealed = _wallet.revealAddressesTo(
      keychain: bdk.KeychainKind.external_,
      index: index,
    );
    for (final info in revealed) {
      info.address.dispose();
    }
    _store.persist();
  }

  @override
  void close() => _store.close();
}

final class _LiquidSession implements NativeWriteSession {
  final LwkWalletStoreDatasource _store;
  Set<String>? _used;

  final String cachePath;

  _LiquidSession(this._store, this.cachePath);

  lwk.Wallet get _wallet => _store.wallet;

  @override
  Future<int> firstUnusedIndex() async {
    final info = await _wallet.addressLastUnused();
    final index = info.index;
    if (index == null) throw const NativeStoreMissing();
    return index;
  }

  @override
  Future<String> address(int index) async =>
      (await _wallet.address(index: index)).confidential;

  @override
  Future<bool> isUsed(int index, String address) async {
    final used = _used ??= {
      for (final tx in await _wallet.txs())
        for (final output in tx.outputs) output.address.confidential,
    };
    return used.contains(address);
  }

  @override
  Future<void> revealAndPersist(int index) async {
    // This SDK has no persisted reveal API. RevisionStoreDatasource's issued high-water
    // is authoritative and must be passed to the engine's stopAtIndex.
    await _wallet.address(index: index);
  }

  @override
  void close() => _store.close();
}

/// Only the SDK session can attest its canonical cache. Test sessions do not
/// provide a path and therefore cannot authorize production Liquid readers.
extension NativeWriteSessionIdentity on NativeWriteSession {
  Future<int?> lastIssuedIndex() async => switch (this) {
    _BitcoinSession(:final _store) => _store.wallet.derivationIndex(
      keychain: bdk.KeychainKind.external_,
    ),
    _LiquidSession() => await firstUnusedIndex(),
    _ => null,
  };

  String? get liquidCachePath => switch (this) {
    _LiquidSession(:final cachePath) => cachePath,
    _ => null,
  };
}
