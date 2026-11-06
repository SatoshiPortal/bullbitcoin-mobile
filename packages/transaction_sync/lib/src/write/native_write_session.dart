import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import '../../transaction_sync.dart';

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
        final exists = File(path).existsSync();
        if (!create && !exists) throw const NativeStoreMissing();
        final network = switch (descriptor.key.network) {
          BitcoinNetwork.mainnet => bdk.Network.bitcoin,
          BitcoinNetwork.testnet => bdk.Network.testnet,
          _ => throw const NativeNetworkUnsupported(),
        };
        if (!exists) {
          // Publish a closed database: a killed create may leave a valid
          // SQLite persister with no wallet. Only staging may be discarded.
          final staging = '$path.creating';
          _deleteSqlite(staging);
          _createBitcoin(staging, descriptor, network);
          File(staging).renameSync(path);
        }
        final kind = network == bdk.Network.bitcoin
            ? bdk.NetworkKind.main
            : bdk.NetworkKind.test;
        final external = bdk.Descriptor(
          descriptor: descriptor.externalDescriptor,
          networkKind: kind,
        );
        bdk.Descriptor? internal;
        bdk.Persister? persister;
        try {
          internal = bdk.Descriptor(
            descriptor: descriptor.internalDescriptor,
            networkKind: kind,
          );
          persister = bdk.Persister.newSqlite(path: path);
          final wallet = bdk.Wallet.load(
            descriptor: external,
            changeDescriptor: internal,
            persister: persister,
            lookahead: 25,
          );
          return _BitcoinSession(wallet, persister);
        } on Object {
          persister?.dispose();
          rethrow;
        } finally {
          external.dispose();
          internal?.dispose();
        }
      case LiquidWalletDescriptor():
        if (!create && !Directory(path).existsSync()) {
          throw const NativeStoreMissing();
        }
        final network = switch (descriptor.key.network) {
          LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
          LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
          _ => throw const NativeNetworkUnsupported(),
        };
        final wallet = await lwk.Wallet.init(
          network: network,
          dbpath: path,
          descriptor: lwk.Descriptor(
            ctDescriptor: descriptor.combinedCtDescriptor,
          ),
        );
        return _LiquidSession(wallet);
    }
  }

  void _createBitcoin(
    String path,
    BitcoinWalletDescriptor descriptor,
    bdk.Network network,
  ) {
    final kind = network == bdk.Network.bitcoin
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;
    final external = bdk.Descriptor(
      descriptor: descriptor.externalDescriptor,
      networkKind: kind,
    );
    bdk.Descriptor? internal;
    bdk.Persister? persister;
    bdk.Wallet? wallet;
    try {
      internal = bdk.Descriptor(
        descriptor: descriptor.internalDescriptor,
        networkKind: kind,
      );
      persister = bdk.Persister.newSqlite(path: path);
      wallet = bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: network,
        persister: persister,
        lookahead: 25,
      );
      wallet.persist(persister: persister);
    } finally {
      wallet?.dispose();
      persister?.dispose();
      external.dispose();
      internal?.dispose();
    }
  }

  void _deleteSqlite(String path) {
    for (final suffix in ['', '-journal', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (file.existsSync()) file.deleteSync();
    }
  }

  @override
  Future<void> delete(WalletKey key) async {
    final path = nativeWalletStoragePath(documentsDirectory, key);
    // Readers hydrate private copies. The coordination lock excludes new
    // Liquid hydrations; unlink does not rely on cross-library SQLite locks.
    switch (key.network) {
      case BitcoinNetwork():
        // The parents sidecar is lane A's disposable cache.
        for (final base in [path, '$path.creating', '$path.parents.sqlite']) {
          _deleteSqlite(base);
        }
      case LiquidNetwork():
        final directory = Directory(path);
        if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
  }
}

final class NativeStoreMissing implements Exception {
  const NativeStoreMissing();
}

final class NativeNetworkUnsupported implements Exception {
  const NativeNetworkUnsupported();
}

bool isLiquidStatusConflict(Object error) =>
    error is lwk.LwkError && error.msg.contains('UpdateOnDifferentStatus');

final class _BitcoinSession implements NativeWriteSession {
  final bdk.Wallet _wallet;
  final bdk.Persister _persister;

  _BitcoinSession(this._wallet, this._persister);

  @override
  Future<int> firstUnusedIndex() async => 0;

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
    final unused = _wallet.listUnusedAddresses(
      keychain: bdk.KeychainKind.external_,
    );
    try {
      return !unused.any((info) => info.index == index);
    } finally {
      for (final info in unused) {
        info.address.dispose();
      }
    }
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
    _wallet.persist(persister: _persister);
  }

  @override
  void close() {
    _wallet.dispose();
    _persister.dispose();
  }
}

final class _LiquidSession implements NativeWriteSession {
  final lwk.Wallet _wallet;
  Set<String>? _used;

  _LiquidSession(this._wallet);

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
    // This SDK has no persisted reveal API. RevisionStore's issued high-water
    // is authoritative and must be passed to the engine's stopAtIndex.
    await _wallet.address(index: index);
  }

  @override
  void close() => _wallet.dispose();
}
