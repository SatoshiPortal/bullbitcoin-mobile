import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;
import 'package:sync/write.dart';

import 'support/connections.dart';

final class _Catalog implements WalletCatalogPort {
  final List<PublicWalletDescriptor> wallets;
  _Catalog(this.wallets);

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => Ok(wallets.singleWhere((wallet) => wallet.key == key));

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      Ok(wallets);
}

final class _Reserved implements ReservedAddressPort {
  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

final class _NoInputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}

void main() {
  late Directory dir;
  late RevisionStoreDatasource revisions;
  late BackgroundSync background;

  final wallet = BitcoinWalletDescriptor(
    key: WalletKey(id: 'background', network: BitcoinNetwork.testnet),
    scriptType: ScriptType.bip84,
    origin: 'public-fixture',
    externalDescriptor: 'wpkh(public/background/0)',
    internalDescriptor: 'wpkh(public/background/1)',
  );
  final catalog = _Catalog([wallet]);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('background-sync-');
    // Only the foreground creates the stores.
    final foreground = openForeground(
      documentsDirectory: dir.path,
      catalog: catalog,
      reservedAddresses: _Reserved(),
      freezes: MemoryFreezeStore(),
      inputReservations: _NoInputReservations(),
      connections: FixtureConnections(const []),
    );
    await foreground.close();
    revisions = RevisionStoreDatasource.openExisting(
      revisionStorePath(dir.path),
    );
    revisions.begin(wallet.key, WriteIntent.create);
    revisions.finish(wallet.key, initializedDescriptor: wallet);
    background = Sync.background(
      documentsDirectory: dir.path,
      catalog: catalog,
      connections: FixtureConnections(const []),
    );
  });

  tearDown(() async {
    await background.close();
    revisions.close();
    dir.deleteSync(recursive: true);
  });

  test('revision is not loaded until a first demand has read it', () async {
    final revision = background.revision(wallet.key);
    expect(revision.now.status, ValueStatus.notLoaded);
    await pumpEventQueue();
    expect(revision.now.status, ValueStatus.ready);
    expect(revision.now.revision, revisions.record(wallet.key)?.state.stamp);
  });

  test('a refresh republishes the revision committed elsewhere', () async {
    final revision = background.revision(wallet.key);
    await pumpEventQueue();
    final before = revision.now.revision;
    // Another isolate commits a revision.
    revisions.begin(wallet.key, WriteIntent.sync);
    revisions.finish(wallet.key);
    final committed = revisions.record(wallet.key)?.state.stamp;
    expect(committed, isNot(before));
    expect(revision.now.revision, before);
    // No server: the refresh fails, and still reads what was committed.
    expect(await background.refresh(wallet.key), isA<Err>());
    expect(revision.now.revision, committed);
  });

  test('once closed, it reads closed and refreshes nothing', () async {
    final revision = background.revision(wallet.key);
    await pumpEventQueue();
    await background.close();
    expect(revision.now.status, ValueStatus.closed);
    expect(
      await background.refresh(wallet.key),
      isA<Err<SyncCompletion, SyncFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<SyncClosedFailure>(),
      ),
    );
  });
}
