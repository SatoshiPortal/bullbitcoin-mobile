import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../../../domain/public_wallet_descriptor.dart';
import 'electrum_cache_datasource.dart';
import 'native_store_errors.dart';

/// The BDK wallet store at its published path. Opening a persister can
/// itself write, so callers hold the writer lock and never retry afterward.
final class BdkWalletStoreDatasource {
  final bdk.Wallet wallet;
  final bdk.Persister _persister;

  BdkWalletStoreDatasource._(this.wallet, this._persister);

  static bdk.Network? network(Network network) => switch (network) {
    BitcoinNetwork.mainnet => bdk.Network.bitcoin,
    BitcoinNetwork.testnet => bdk.Network.testnet,
    BitcoinNetwork.regtest => bdk.Network.regtest,
    _ => null,
  };

  static bdk.NetworkKind _kind(bdk.Network network) =>
      network == bdk.Network.bitcoin
      ? bdk.NetworkKind.main
      : bdk.NetworkKind.test;

  /// Loads an existing store. Throws [NativeStoreMissing] when it is absent,
  /// so loading never creates one, and [NativeNetworkUnsupported] when the
  /// store or the key belongs to another network.
  static BdkWalletStoreDatasource load(
    String path,
    BitcoinWalletDescriptor descriptor,
  ) {
    if (!File(path).existsSync()) throw const NativeStoreMissing();
    final expected = network(descriptor.key.network);
    if (expected == null) throw const NativeNetworkUnsupported();
    final kind = _kind(expected);
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
      if (wallet.network() != expected) {
        wallet.dispose();
        throw const NativeNetworkUnsupported();
      }
      return BdkWalletStoreDatasource._(wallet, persister);
    } on Object {
      persister?.dispose();
      rethrow;
    } finally {
      external.dispose();
      internal?.dispose();
    }
  }

  /// Publishes a closed database: a killed create may leave a valid SQLite
  /// persister with no wallet, so only the staging file may be discarded.
  static void create(String path, BitcoinWalletDescriptor descriptor) {
    final expected = network(descriptor.key.network);
    if (expected == null) throw const NativeNetworkUnsupported();
    final staging = '$path.creating';
    _deleteSqlite(staging);
    final kind = _kind(expected);
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
      persister = bdk.Persister.newSqlite(path: staging);
      wallet = bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: expected,
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
    File(staging).renameSync(path);
  }

  /// Removes the store, an interrupted creation and the disposable parents
  /// sidecar.
  static void delete(String path) {
    for (final base in [
      path,
      '$path.creating',
      ElectrumCacheDatasource.pathFor(path),
    ]) {
      _deleteSqlite(base);
    }
  }

  static void _deleteSqlite(String path) {
    for (final suffix in ['', '-journal', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// True when the persister wrote changes.
  bool persist() => wallet.persist(persister: _persister);

  void close() {
    wallet.dispose();
    _persister.dispose();
  }
}
