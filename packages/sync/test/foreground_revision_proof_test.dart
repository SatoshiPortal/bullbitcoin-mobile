import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:sync/inventory.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import '../../secrets/test/support/view_fixture.dart';
import 'support/connections.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final visibleWallet = viewWallet('visible');
  final hiddenWallet = viewWallet('hidden');
  final visible = WalletKey(
    id: visibleWallet.id,
    network: BitcoinNetwork.testnet,
  );
  final hidden = WalletKey(
    id: hiddenWallet.id,
    network: BitcoinNetwork.testnet,
  );
  late ViewFixture fixture;
  late SecretsInventory inventory;
  late String directory;
  late String gate;

  setUp(() async {
    fixture = await ViewFixture.create();
    addTearDown(fixture.close);
    directory = '${fixture.directory.path}/native';
    gate = '${fixture.directory.path}/gate';
    inventory = ok(
      await SecretsInventory.open(
        file: fixture.file,
        admission: fixture.admission,
        authority: SessionAuthority(),
      ),
    );
    await inventory.insertWalletInViewForTesting(
      view: 'all',
      wallet: visibleWallet,
    );
    await inventory.insertWalletInViewForTesting(
      view: 'all',
      wallet: hiddenWallet,
    );
    // A real wallet row without membership; the application gate stays off.
    await fixture.sql([
      "DELETE FROM view_members WHERE member = 'wallet:${hiddenWallet.id}'",
    ]);
  });

  void seedRevisions() {
    final store = RevisionStoreDatasource.openForeground(
      revisionStorePath(directory),
    );
    try {
      for (final key in [visible, hidden]) {
        store.begin(key, WriteIntent.create);
        store.finish(key);
      }
    } finally {
      store.close();
    }
  }

  ({WalletNativeRuntime runtime, LifecycleHandle owner}) mount({
    Future<String> Function()? documentsDirectory,
    FreezeStorePort? freezes,
    void Function(ForegroundStores)? onStoresOpened,
    Future<void> Function()? afterRevisionRead,
    Future<Result<void, SyncFailure>> Function()? afterStoresClosed,
  }) {
    final connections = FixtureConnections([]);
    addTearDown(() => expect(connections.attempts, 0));
    return WalletNativeRuntime.foregroundRevisionProof(
      admission: fixture.admission,
      catalog: SecretsWalletCatalog.foreground(inventory),
      reserved: const NoReservedAddresses(),
      inputReservations: NoInputReservations(),
      sync: ElectrumSync(
        connections: connections,
        documentsDirectory: () async => throw StateError('Unexpected sync'),
        readRevision: (_) async => throw StateError('Unexpected sync'),
      ),
      documentsDirectory: documentsDirectory ?? () async => directory,
      freezes: freezes ?? MemoryFreezeStore(),
      connections: connections,
      onStoresOpened: onStoresOpened,
      afterRevisionRead: afterRevisionRead,
      afterStoresClosed: afterStoresClosed,
    );
  }

  test(
    'lock during directory resolution prevents the actual store open',
    () async {
      final entered = Completer<void>();
      final resolved = Completer<String>();
      var opened = 0;
      final proof = mount(
        documentsDirectory: () {
          entered.complete();
          return resolved.future;
        },
        onStoresOpened: (_) => opened++,
      );
      final file = File(revisionStorePath(directory));
      expect(file.existsSync(), isFalse);
      final reading = proof.runtime.readRevision(visible);
      await entered.future;

      expect(await inventory.lock(), isTrue);
      final closing = fixture.admission.close();
      expect(await _probeExclusive(gate), 'busy');
      resolved.complete(directory);
      _expectFailure<SyncClosedFailure>(await reading);
      await closing;

      expect(opened, 0);
      expect(file.existsSync(), isFalse);
      expect(await _probeExclusive(gate), 'acquired');
    },
  );

  test(
    'a real admitted revision drains before the entire lease closes',
    () async {
      seedRevisions();
      final entered = Completer<void>();
      final finish = Completer<void>();
      final remainingOwner = Completer<void>();
      final finishOwner = Completer<void>();
      // Registered before the runtime, so admission closes the runtime first.
      fixture.admission.track(() {
        remainingOwner.complete();
        return finishOwner.future;
      });
      WalletRevisionReaderPort? reader;
      var opened = 0;
      var physicalClose = 0;
      var nativeReads = 0;
      var holdRead = false;
      final freezes = _FreezeReadProbe();
      final proof = mount(
        freezes: freezes,
        onStoresOpened: (stores) {
          opened++;
          reader = stores.revisions;
        },
        afterRevisionRead: () async {
          nativeReads++;
          if (!holdRead) return;
          entered.complete();
          await finish.future;
        },
        afterStoresClosed: () async {
          physicalClose++;
          return const Ok(null);
        },
      );
      expect(opened, 0);
      const point = (txId: 'fixture', vout: 0);
      _expectFailure<SyncClosedFailure>(
        await proof.runtime.listAttributedFreezes(),
      );
      _expectFailure<SyncClosedFailure>(
        await proof.runtime.freezeAttributedOutpoints([
          const FrozenOutpoint(point, origin: ''),
        ]),
      );
      _expectFailure<SyncClosedFailure>(
        await proof.runtime.freezeWalletOutpoints(visible, [point]),
      );
      _expectFailure<SyncClosedFailure>(
        await proof.runtime.unfreezeOutpoints([point]),
      );
      _expectFailure<SyncClosedFailure>(
        await proof.runtime.withBitcoinRevisionAdmission(
          visible,
          (_) async => fail('A raw spend admission escaped the proof'),
        ),
      );
      _expectFailure<SyncClosedFailure>(
        await proof.runtime.readReservedOutpointsForDisplay(),
      );
      _expectFailure<SyncClosedFailure>(
        await proof.runtime.readFrozenOutpoints(),
      );
      expect(freezes.reads, 0);
      expect(opened, 0);
      _expectFailure<SyncNotFoundFailure>(
        await proof.runtime.readRevision(hidden),
      );
      expect(nativeReads, 0);
      final raw = present(reader);
      expect(ok(await raw.read(hidden)).stamp.key, hidden);
      expect(ok(await proof.runtime.readRevision(visible)).stamp.key, visible);
      expect(nativeReads, 1);
      final warmReads = freezes.reads;
      _expectFailure<SyncClosedFailure>(
        await proof.runtime.readFrozenOutpoints(),
      );
      expect(freezes.reads, warmReads);

      holdRead = true;
      final reading = proof.runtime.readRevision(visible);
      await entered.future;
      expect(ok(await raw.read(visible)).stamp.key, visible);
      final closing = fixture.admission.close();
      final disposer = proof.owner.close();
      expect(proof.owner.close(), same(disposer));
      final stopping = proof.runtime.close();
      expect(proof.runtime.close(), same(stopping));
      _expectFailure<SyncClosedFailure>(
        await proof.runtime.readRevision(visible),
      );
      expect(await _probeExclusive(gate), 'busy');
      expect(remainingOwner.isCompleted, isFalse);
      expect(physicalClose, 0);
      expect(ok(await raw.read(visible)).stamp.key, visible);

      finish.complete();
      _expectFailure<SyncClosedFailure>(await reading);
      await disposer;
      ok(await stopping);
      await remainingOwner.future;
      await expectLater(raw.read(visible), throwsA(_closedDatabase));
      expect(physicalClose, 1);
      expect(await _probeExclusive(gate), 'busy');
      finishOwner.complete();
      await closing;
      expect(await _probeExclusive(gate), 'acquired');
    },
  );

  test(
    'unconfirmed close keeps the real lease through repeated attempts',
    () async {
      seedRevisions();
      WalletRevisionReaderPort? reader;
      var acknowledgements = 0;
      final proof = mount(
        onStoresOpened: (stores) => reader = stores.revisions,
        afterStoresClosed: () async {
          // Fail acknowledgement, not sqlite3.close; the actual DB close is
          // independently observable while the native lock stays held.
          acknowledgements++;
          return const Err(SyncStorageFailure());
        },
      );
      final state = ok(await proof.runtime.readRevision(visible));
      expect(state.stamp.key, visible);
      expect(state.stamp.generation, 1);
      final stopping = proof.runtime.close();
      _expectFailure<SyncStorageFailure>(await stopping);
      expect(proof.runtime.close(), same(stopping));
      await expectLater(
        present(reader).read(visible),
        throwsA(_closedDatabase),
      );
      await expectLater(
        proof.owner.close(),
        throwsA(_reason('native_runtime_close_unconfirmed')),
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          fixture.admission.close(),
          throwsA(_reason('resources_still_open')),
        );
        expect(await _probeExclusive(gate), 'busy');
      }
      expect(acknowledgements, 1);
      // The poisoned test admission intentionally stays quarantined until
      // process exit. ViewFixture removes its private temporary pathname.
    },
  );
}

void _expectFailure<F extends SyncFailure>(
  Result<Object?, SyncFailure> result,
) => expect(
  result,
  isA<Err<Object?, SyncFailure>>().having(
    (result) => result.failure,
    'failure',
    isA<F>(),
  ),
);

Matcher _reason(String value) =>
    isA<LifecycleException>().having((error) => error.reason, 'reason', value);

final _closedDatabase = isA<StateError>().having(
  (error) => error.message,
  'message',
  'This database has already been closed',
);

Future<String> _probeExclusive(String path) => Isolate.run(() async {
  try {
    final lease = await NativeFileGate(File(path))
        .acquire(exclusive: true, timeout: Duration.zero);
    await lease.close();
    return 'acquired';
  } on LifecycleException catch (error) {
    return error.reason;
  }
});

final class _FreezeReadProbe implements FreezeStorePort {
  int reads = 0;

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() async {
    reads++;
    return const Ok([]);
  }

  @override
  Future<Result<void, SyncFailure>> freeze(List<FrozenOutpoint> rows) =>
      throw StateError('Unexpected freeze');

  @override
  Future<Result<void, SyncFailure>> unfreeze(List<Outpoint> outpoints) =>
      throw StateError('Unexpected unfreeze');
}
