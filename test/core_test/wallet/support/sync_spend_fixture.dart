import 'wallet_model.dart';

import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:primitives/primitives.dart' as p;
import 'package:sync/sync.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;
import 'package:sync/write.dart';

import 'package:sync/testing.dart'
    show NoConnections, NoInputReservations, NoReservedAddresses;

/// A foreground [Sync] over [documentsDirectory] holding one real BDK store
/// for [model], so spends run through sync's writer exactly as in the app.
/// Native fixture writes stay here, in tests.
final class SyncSpendFixture {
  final Sync sync;
  final WalletKey key;
  final String documentsDirectory;
  final BitcoinWalletDescriptor descriptor;
  final MemoryFreezeStore freezes;

  SyncSpendFixture._(
    this.sync,
    this.key,
    this.documentsDirectory,
    this.descriptor,
    this.freezes,
  );

  static Future<SyncSpendFixture> open(
    String documentsDirectory,
    PublicBdkWalletModel model, {
    InputReservationPort? reservations,
  }) async {
    final key = WalletKey(id: model.id, network: model.network.shared);
    final descriptor = BitcoinWalletDescriptor(
      key: key,
      scriptType: p.ScriptType.bip84,
      origin: 'test-fixture',
      externalDescriptor: model.externalDescriptor,
      internalDescriptor: model.internalDescriptor,
    );
    final freezes = MemoryFreezeStore();
    final sync = Sync.foreground(
      documentsDirectory: documentsDirectory,
      catalog: _Catalog(descriptor),
      reservedAddresses: const NoReservedAddresses(),
      freezes: freezes,
      inputReservations: reservations ?? NoInputReservations(),
      connections: const NoConnections(),
    );
    switch (await sync.stores.writer.create(key, expectedGeneration: 0)) {
      case p.Ok():
        break;
      case p.Err(:final failure):
        throw StateError('fixture store: ${failure.logCode}');
    }
    return SyncSpendFixture._(
      sync,
      key,
      documentsDirectory,
      descriptor,
      freezes,
    );
  }

  /// [walletId]'s handle, as the app's runtime hands it out.
  Future<Wallet> wallet(String walletId) async =>
      switch (await sync.wallet(key)) {
        p.Ok(:final value) => value,
        p.Err(:final failure) => throw StateError(failure.logCode),
      };

  /// Runs [body] on the native store, as a sync pass would, then persists.
  void onStore(void Function(bdk.Wallet wallet) body) {
    final kind = key.network == p.BitcoinNetwork.mainnet
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;
    final persister = bdk.Persister.newSqlite(
      path: nativeWalletStoragePath(documentsDirectory, key),
    );
    final wallet = bdk.Wallet.load(
      descriptor: bdk.Descriptor(
        descriptor: descriptor.externalDescriptor,
        networkKind: kind,
      ),
      changeDescriptor: bdk.Descriptor(
        descriptor: descriptor.internalDescriptor,
        networkKind: kind,
      ),
      persister: persister,
      lookahead: 25,
    );
    try {
      body(wallet);
      wallet.persist(persister: persister);
    } finally {
      wallet.dispose();
      persister.dispose();
    }
  }

  Future<void> close() => sync.close();
}

final class _Catalog implements WalletCatalogPort {
  final PublicWalletDescriptor descriptor;
  _Catalog(this.descriptor);

  @override
  Future<p.Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => key == descriptor.key
      ? p.Ok(descriptor)
      : const p.Err(SyncNotFoundFailure());

  @override
  Future<p.Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      p.Ok([descriptor]);
}
