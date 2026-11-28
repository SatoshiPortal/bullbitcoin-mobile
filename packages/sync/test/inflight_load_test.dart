import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/freeze_authority.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/wallet_projections.dart';
import 'package:sync/src/public/sync.dart'
    show SyncForegroundStores, walletOver;
import 'package:sync/sync.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;

import 'support/connections.dart';
import 'support/projection_fakes.dart';
import 'support/regtest_wallet.dart';

/// A load whose mapping is suspended must not publish once a delete or a
/// re-import invalidated the generation it was loading.
void main() {
  test('foreground close drains a revision-triggered reload', () async {
    final directory = Directory.systemTemp.createTempSync('sync-close-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final descriptor = regtestDescriptor();
    final catalog = _SuspendedCatalog(descriptor);
    final sync = Sync.foreground(
      documentsDirectory: directory.path,
      catalog: catalog,
      reservedAddresses: NoReservedAddresses(),
      freezes: MemoryFreezeStore(),
      inputReservations: _NoInputReservations(),
      connections: FixtureConnections(const []),
    );
    final revisions = RevisionStoreDatasource.openExisting(
      revisionStorePath(directory.path),
    );
    addTearDown(revisions.close);
    addTearDown(sync.close);
    final key = descriptor.key;
    revisions.begin(key, WriteIntent.create);
    revisions.finish(key, initializedDescriptor: descriptor);
    final wallet = (await sync.wallet(key) as Ok<Wallet, SyncFailure>).value;
    final observation = wallet.balances.watch().listen((_) {});
    addTearDown(observation.cancel);

    // A worker committed a newer revision. The foreground read publishes it
    // and starts a reload, which pauses before entering the SQLite reader.
    revisions.begin(key, WriteIntent.sync);
    revisions.finish(key);
    expect(await sync.stores.revisions.read(key), isA<Ok>());
    await catalog.entered.future;

    var completed = 0;
    final first = sync.close().then((_) => completed++);
    final second = sync.close().then((_) => completed++);
    // Let both close calls run through their asynchronous cleanup.
    await pumpEventQueue(times: 1);
    final completedBeforeRelease = completed;
    catalog.release.complete();
    await Future.wait([first, second]);
    expect(completedBeforeRelease, 0);
    expect(wallet.balances.now.status, ValueStatus.closed);
  });

  final key = WalletKey(id: 'inflight', network: BitcoinNetwork.testnet);
  late ScriptedRevisions revisions;
  late ScriptedSource source;
  late WalletProjections projections;
  late Wallet wallet;

  setUp(() async {
    revisions = ScriptedRevisions(key);
    source = ScriptedSource(revisions);
    projections = WalletProjections(
      freezes: FreezeAuthority(MemoryFreezeStore()),
      revisions: revisions,
      changes: revisions.changes.stream,
      source: source,
    );
    wallet = walletOver(projections, key, 0);
    expect(await wallet.load(), isA<Ok<WalletRevision, SyncFailure>>());
  });
  tearDown(() => projections.close());

  Matcher notFound<T extends Object>() => isA<Err<T, SyncFailure>>().having(
    (err) => err.failure,
    'failure',
    isA<SyncNotFoundFailure>(),
  );

  /// Starts a load of the next commit and holds it inside the mapping.
  Future<Future<Result<WalletRevision, SyncFailure>>> suspendedLoad() async {
    revisions.commit();
    source
      ..mapping = Completer<void>()
      ..mappingEntered = Completer<void>();
    final loading = wallet.load();
    await source.mappingEntered.future;
    return loading;
  }

  test('a delete observed during the mapping dominates', () async {
    final loading = await suspendedLoad();
    revisions
      ..delete()
      ..emit();
    await Future<void>.delayed(Duration.zero);
    expect(wallet.balances.now.failure, isA<SyncNotFoundFailure>());

    source.mapping?.complete();
    final result = await loading;
    final balances = wallet.balances.now;
    expect(balances.status, ValueStatus.unavailable);
    expect(balances.failure, isA<SyncNotFoundFailure>());
    expect(balances.data, isNull);
    expect(result, notFound<WalletRevision>());
  });

  test('a re-import committed during the mapping is never published to the '
      'old handle', () async {
    final loading = await suspendedLoad();
    revisions.reimport();

    source.mapping?.complete();
    final result = await loading;
    final balances = wallet.balances.now;
    expect(balances.status, ValueStatus.unavailable);
    expect(balances.failure, isA<SyncNotFoundFailure>());
    expect(result, notFound<WalletRevision>());
    expect(await wallet.ownership(), notFound<OwnershipIndex>());
  });
}

final class _SuspendedCatalog implements WalletCatalogPort {
  final PublicWalletDescriptor descriptor;
  final entered = Completer<void>();
  final release = Completer<void>();

  _SuspendedCatalog(this.descriptor);

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async {
    entered.complete();
    await release.future;
    return Ok(descriptor);
  }

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      Ok([descriptor]);
}

final class _NoInputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}
