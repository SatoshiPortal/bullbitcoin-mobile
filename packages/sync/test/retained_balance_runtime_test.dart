import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/storage.dart';
import 'package:sync/inventory.dart';
import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/write/datasources/bdk_wallet_store_datasource.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import '../../secrets/test/support/open_inventory.dart';
import 'support/connections.dart';
import 'support/regtest_wallet.dart' show regtestDescriptor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(BullSdk.init);
  late Directory temp;
  late String directory;
  late SecretsInventory inventory;
  late WalletNativeRuntime runtime;
  late int opens;
  late int directoryRequests;
  late BitcoinWalletDescriptor bitcoin;
  late WalletKey liquid;
  late Map<String, dynamic> liquidFixture;
  late Future<void> Function()? beforeOpening;
  late Future<void> Function()? beforeHydration;
  late Future<void> Function()? beforePublication;
  late BalanceEnvironment? environment;
  late ForegroundStores stores;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('retained-balance-');
    directory = '${temp.path}/native';
    final fixture = await openFreshInventory(temp);
    inventory = fixture.inventory;
    final connections = FixtureConnections([]);
    opens = 0;
    directoryRequests = 0;
    beforeOpening = null;
    beforeHydration = null;
    beforePublication = null;
    environment = (environment: NetworkEnv.regtest, epoch: 0);
    runtime = WalletNativeRuntime.open(
      catalog: SecretsWalletCatalog.foreground(inventory),
      reserved: const NoReservedAddresses(),
      inputReservations: NoInputReservations(),
      deleteCatalogEntry: SecretsWalletCatalog.removal(inventory),
      sync: ElectrumSync(
        connections: connections,
        documentsDirectory: () async => throw StateError('Unexpected sync'),
        readRevision: (_) async => throw StateError('Unexpected sync'),
      ),
      documentsDirectory: () async {
        directoryRequests++;
        await beforeOpening?.call();
        return directory;
      },
      freezes: MemoryFreezeStore(),
      connections: connections,
      onStoresOpened: (opened) {
        opens++;
        stores = opened;
      },
      beforeBalanceHydration: () async => beforeHydration?.call(),
      beforeBalancePublication: () async => beforePublication?.call(),
    );
    addTearDown(() async {
      valueOf(await runtime.close());
      await inventory.close();
      await fixture.admission.close();
      await temp.delete(recursive: true);
      expect(connections.attempts, 0);
    });
    final vector = regtestDescriptor();
    bitcoin = BitcoinWalletDescriptor(
      key: WalletKey(
        id: '${vector.origin}:regtest',
        network: BitcoinNetwork.regtest,
      ),
      scriptType: vector.scriptType,
      origin: vector.origin,
      externalDescriptor: vector.externalDescriptor,
      internalDescriptor: vector.internalDescriptor,
    );
    liquid = WalletKey(
      id: 'elwpkh([73c5da0a/84h/1h/0h]):regtest',
      network: LiquidNetwork.regtest,
    );
    liquidFixture = jsonDecode(
      await File('test/fixtures/retained_liquid_deposit.json').readAsString(),
    ) as Map<String, dynamic>;
    valueOf(
      await inventory.registerWallet(
        watchOnlyWallet(
          bitcoin.key.id,
          network: 'bitcoinRegtest',
          external: bitcoin.externalDescriptor,
          internal: bitcoin.internalDescriptor,
        ),
      ),
    );
    valueOf(
      await inventory.registerWallet(
        watchOnlyWallet(
          liquid.id,
          network: 'liquidRegtest',
          external: liquidFixture['descriptor'] as String,
        ),
      ),
    );
  });

  WalletCatalogueStamp capture() {
    final stamp = inventory.walletCatalogue.capture();
    if (stamp == null) throw StateError('Inventory must be open');
    return stamp;
  }

  Future<WalletRevision> publish(WalletKey key) async =>
      valueOf(await valueOf(await runtime.wallet(key)).load());

  RetainedBalanceDemand demand(WalletKey key) {
    final origin = runtime.captureBalanceDemand(key, () => environment);
    if (origin == null) throw StateError('Expected a current admission');
    return origin;
  }

  Future<WalletRevision> retain(WalletKey key) async =>
      valueOf(await runtime.demandRetainedBalance(demand(key)));

  test(
    'a request before the first await cannot publish under a replacement grant',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      beforeOpening = () async {
        entered.complete();
        await release.future;
      };
      final oldRequest = runtime.loadWallet(bitcoin.key);
      await entered.future;
      final first = capture();
      final views = inventory.openedViews;
      if (views == null) throw StateError('Expected an opened view');
      valueOf(await views.activate(views.views.single.id));
      expect(inventory.walletCatalogue.isCurrent(first), isFalse);
      release.complete();
      expect(await oldRequest, isA<Err>());
      final current = capture();
      final native = valueOf(await runtime.readRevision(bitcoin.key)).stamp;
      expect(runtime.readRetainedBalance(current, native), isA<Err>());
      expect(await publish(bitcoin.key), native);
      expect(
        valueOf(runtime.readRetainedBalance(current, native)),
        BigInt.zero,
      );
    },
  );

  test(
    'cold read creates nothing; first publication needs explicit demand',
    () async {
      final catalogue = capture();
      final guessed = WalletRevision(
        key: bitcoin.key,
        generation: 1,
        revision: 1,
      );
      expect(runtime.readRetainedBalance(catalogue, guessed), isA<Err>());
      expect(
        await runtime.demandRetainedBalance(demand(bitcoin.key)),
        isA<Err>(),
      );
      expect(directoryRequests, 0);
      expect(opens, 0);
      expect(Directory(directory).existsSync(), isFalse);
      valueOf(await runtime.initialize());
      valueOf(await runtime.refreshAll());
      final revision = valueOf(await runtime.readRevision(bitcoin.key)).stamp;
      expect(runtime.readRetainedBalance(catalogue, revision), isA<Err>());
      expect(await retain(bitcoin.key), revision);
      expect(
        runtime.readRetainedBalance(catalogue, revision),
        isA<Ok<BigInt, SyncFailure>>().having(
          (result) => result.value,
          'total',
          BigInt.zero,
        ),
      );
      final liquidRevision = valueOf(await runtime.readRevision(liquid)).stamp;
      expect(
        runtime.readRetainedBalance(catalogue, liquidRevision),
        isA<Err>(),
      );
      expect(await retain(liquid), liquidRevision);
      expect(
        valueOf(runtime.readRetainedBalance(catalogue, liquidRevision)),
        BigInt.zero,
      );
      expect(opens, 1);
    },
  );

  test('first explicit demand reads nonzero on both chains', () async {
    final catalogue = capture();
    valueOf(await runtime.initialize());

    final store = RevisionStoreDatasource.openExisting(
      revisionStorePath(directory),
    );
    addTearDown(store.close);
    store.begin(bitcoin.key, WriteIntent.sync);
    final bdkStore = BdkWalletStoreDatasource.load(
      nativeWalletStoragePath(directory, bitcoin.key),
      bitcoin,
    );
    try {
      final address = bdkStore.wallet
          .peekAddress(keychain: bdk.KeychainKind.external_, index: 0)
          .address;
      final script = address.scriptPubkey().toBytes();
      address.dispose();
      final amount = ByteData(8)..setUint64(0, 54321, Endian.little);
      final raw = BytesBuilder()
        ..add([2, 0, 0, 0, 1])
        ..add(List.filled(32, 0x11))
        ..add([0, 0, 0, 0, 0, 255, 255, 255, 255, 1])
        ..add(amount.buffer.asUint8List())
        ..add([script.length])
        ..add(script)
        ..add([0, 0, 0, 0]);
      final tx = bdk.Transaction(transactionBytes: raw.toBytes());
      try {
        bdkStore.wallet.applyUnconfirmedTxs(
          unconfirmedTxs: [bdk.UnconfirmedTx(tx: tx, lastSeen: 1)],
        );
        bdkStore.persist();
      } finally {
        tx.dispose();
      }
    } finally {
      bdkStore.close();
    }
    final btcFunded = store.finish(bitcoin.key).stamp;
    store.begin(liquid, WriteIntent.sync);
    final update = File(
      '${nativeWalletStoragePath(directory, liquid)}/${liquidFixture['path']}',
    );
    await update.parent.create(recursive: true);
    await update.writeAsBytes(base64Decode(liquidFixture['update'] as String));
    final liquidFunded = store.finish(liquid).stamp;
    expect(runtime.readRetainedBalance(catalogue, btcFunded), isA<Err>());
    expect(runtime.readRetainedBalance(catalogue, liquidFunded), isA<Err>());
    valueOf(await runtime.refreshAll());
    expect(await retain(bitcoin.key), btcFunded);
    expect(await retain(liquid), liquidFunded);
    expect(
      valueOf(runtime.readRetainedBalance(catalogue, btcFunded)),
      BigInt.from(54321),
    );
    expect(
      valueOf(runtime.readRetainedBalance(catalogue, liquidFunded)),
      BigInt.from(12345),
    );
    final otherNetwork = WalletRevision(
      key: WalletKey(id: bitcoin.key.id, network: LiquidNetwork.regtest),
      generation: btcFunded.generation,
      revision: btcFunded.revision,
    );
    expect(runtime.readRetainedBalance(catalogue, otherNetwork), isA<Err>());
    expect(
      await runtime.demandRetainedBalance(demand(otherNetwork.key)),
      isA<Err>(),
    );
    expect(opens, 1);
  });

  test(
    'pending at the same stamp, tombstone and recreation are refused silently',
    () async {
      final catalogue = capture();
      valueOf(await runtime.initialize());
      final stamp = await retain(bitcoin.key);
      final store = RevisionStoreDatasource.openExisting(
        revisionStorePath(directory),
      );
      addTearDown(store.close);
      await pumpEventQueue();
      final emitted = <WalletRevisionState>[];
      final subscription = runtime.changes.listen(emitted.add);
      addTearDown(subscription.cancel);
      store.begin(bitcoin.key, WriteIntent.sync);
      expect(store.record(bitcoin.key)?.state.stamp, stamp);
      expect(
        await runtime.demandRetainedBalance(demand(bitcoin.key)),
        isA<Err<WalletRevision, SyncFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SyncBusyFailure>(),
        ),
      );
      expect(
        runtime.readRetainedBalance(catalogue, stamp),
        isA<Err<BigInt, SyncFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SyncBusyFailure>(),
        ),
      );
      store.finish(bitcoin.key);
      store.begin(bitcoin.key, WriteIntent.delete);
      expect(runtime.readRetainedBalance(catalogue, stamp), isA<Err>());
      store.finish(bitcoin.key);
      expect(
        await runtime.demandRetainedBalance(demand(bitcoin.key)),
        isA<Err<WalletRevision, SyncFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<SyncNotFoundFailure>(),
        ),
      );
      store.begin(bitcoin.key, WriteIntent.create);
      final recreated = store.finish(bitcoin.key).stamp;
      expect(recreated.generation, isNot(stamp.generation));
      expect(runtime.readRetainedBalance(catalogue, recreated), isA<Err>());
      await pumpEventQueue();
      expect(emitted, isEmpty);
    },
  );

  test(
    'A1, replacement, A2 and a label commit never relabel a cached frame',
    () async {
      final a1 = capture();
      valueOf(await runtime.initialize());
      final stamp = await retain(bitcoin.key);
      final views = inventory.openedViews;
      if (views == null) throw StateError('Expected an opened view');
      final view = views.views.single.id;
      valueOf(await views.activate(view));
      final b = capture();
      valueOf(await views.activate(view));
      final a2 = capture();
      expect(a2.grant, isNot(same(b.grant)));
      for (final owner in [a1, b, a2]) {
        expect(runtime.readRetainedBalance(owner, stamp), isA<Err>());
      }
      expect(await retain(bitcoin.key), stamp);
      expect(valueOf(runtime.readRetainedBalance(a2, stamp)), BigInt.zero);
      valueOf(
        await inventory.setWalletProperties(
          id: bitcoin.key.id,
          label: 'new name',
          birthday: null,
          isDefault: false,
        ),
      );
      final renamed = capture();
      expect(renamed.grant, same(a2.grant));
      expect(runtime.readRetainedBalance(a2, stamp), isA<Err>());
      expect(runtime.readRetainedBalance(renamed, stamp), isA<Err>());
      valueOf(await runtime.refreshAll());
      await pumpEventQueue();
      expect(runtime.readRetainedBalance(renamed, stamp), isA<Err>());
      expect(await retain(bitcoin.key), stamp);
      expect(valueOf(runtime.readRetainedBalance(renamed, stamp)), BigInt.zero);
      final closing = runtime.close();
      expect(runtime.readRetainedBalance(renamed, stamp), isA<Err>());
      valueOf(await closing);
    },
  );

  test(
    'demand refuses an initialization in progress without waiting',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      beforeOpening = () async {
        entered.complete();
        await release.future;
      };
      final candidate = demand(bitcoin.key);
      final initializing = runtime.initialize();
      try {
        await entered.future;
        expect(await runtime.demandRetainedBalance(candidate), isA<Err>());
        expect(directoryRequests, 1);
      } finally {
        release.complete();
      }
      valueOf(await initializing);
      expect(await retain(bitcoin.key), isA<WalletRevision>());
      expect(opens, 1);
    },
  );

  test(
    'environment A-B-A abandons queued demand and maps on the new epoch',
    () async {
      valueOf(await runtime.initialize());
      var notifications = 0;
      final subscription = runtime.retainedBalanceChanges.listen(
        (_) => notifications++,
      );
      addTearDown(subscription.cancel);
      final original = demand(bitcoin.key);
      final stamp = await retain(bitcoin.key);
      await pumpEventQueue();
      expect(notifications, 1);
      final entered = Completer<void>();
      final release = Completer<void>();
      var mappings = 0;
      beforeHydration = () async {
        if (++mappings == 1) {
          entered.complete();
          await release.future;
        }
      };
      final underway = runtime.demandRetainedBalance(original);
      await entered.future;
      final queued = runtime.demandRetainedBalance(original);
      environment = null;
      expect(
        runtime.captureBalanceDemand(bitcoin.key, () => environment),
        isNull,
      );
      environment = (environment: NetworkEnv.testnet, epoch: 1);
      expect(
        runtime.captureBalanceDemand(bitcoin.key, () => environment),
        isNull,
      );
      environment = (environment: NetworkEnv.regtest, epoch: 2);
      expect(original.isCurrent, isFalse);
      final replacement = runtime.demandRetainedBalance(demand(bitcoin.key));
      release.complete();
      expect(await underway, isA<Err>());
      expect(await queued, isA<Err>());
      expect(valueOf(await replacement), stamp);
      await pumpEventQueue();
      expect(mappings, 2);
      expect(notifications, 2);
      expect(opens, 1);
    },
  );

  test(
    'catalogue mutation in the reader queue never reaches hydration',
    () async {
      valueOf(await runtime.initialize());
      final old = demand(bitcoin.key);
      final stamp = valueOf(stores.retainedRevision(bitcoin.key)).stamp;
      final entered = Completer<void>();
      final release = Completer<void>();
      final blocker = stores.reader.readBalance(
        stamp,
        SecretsWalletCatalog.foreground(inventory),
        isCurrent: () => true,
        acquireExisting: stores.acquireExistingRead,
        beforeHydration: () async {
          entered.complete();
          await release.future;
        },
        map: (_) async => BigInt.zero,
      );
      await entered.future;
      var demandHydrations = 0;
      beforeHydration = () async => demandHydrations++;
      final waiting = runtime.demandRetainedBalance(old);
      await pumpEventQueue();
      expect(demandHydrations, 0);
      try {
        valueOf(
          await inventory.setWalletProperties(
            id: bitcoin.key.id,
            label: 'reader queue rename',
            birthday: null,
            isDefault: false,
          ),
        );
      } finally {
        release.complete();
      }
      expect(await blocker, isA<Ok>());
      expect(await waiting, isA<Err>());
      expect(demandHydrations, 0);
      expect(runtime.readRetainedBalance(capture(), stamp), isA<Err>());
      expect(await retain(bitcoin.key), stamp);
      expect(demandHydrations, 1);
    },
  );

  test(
    'pending before publication and close during demand deliver nothing',
    () async {
      valueOf(await runtime.initialize());
      final key = bitcoin.key;
      final stamp = valueOf(stores.retainedRevision(key)).stamp;
      final store = RevisionStoreDatasource.openExisting(
        revisionStorePath(directory),
      );
      addTearDown(store.close);
      var notifications = 0;
      final subscription = runtime.retainedBalanceChanges.listen(
        (_) => notifications++,
      );
      addTearDown(subscription.cancel);
      var entered = Completer<void>();
      var release = Completer<void>();
      beforePublication = () async {
        entered.complete();
        await release.future;
      };
      final candidate = demand(key);
      final pending = runtime.demandRetainedBalance(candidate);
      await entered.future;
      store.begin(key, WriteIntent.sync);
      expect(store.record(key)?.state.stamp, stamp);
      release.complete();
      expect(await pending, isA<Err>());
      store.finish(key);
      expect(
        runtime.readRetainedBalance(candidate.catalogue, stamp),
        isA<Err>(),
      );

      entered = Completer<void>();
      release = Completer<void>();
      final unfinished = runtime.demandRetainedBalance(candidate);
      await entered.future;
      final closing = runtime.close();
      var closed = false;
      final observedClose = closing.then((result) {
        closed = true;
        return result;
      });
      await pumpEventQueue();
      expect(closed, isFalse);
      expect(
        runtime.readRetainedBalance(candidate.catalogue, stamp),
        isA<Err>(),
      );
      expect(await runtime.demandRetainedBalance(candidate), isA<Err>());
      release.complete();
      expect(await unfinished, isA<Err>());
      valueOf(await observedClose);
      expect(notifications, 0);
    },
  );

  test('missing lease and native store are not created by demand', () async {
    valueOf(await runtime.initialize());
    final key = bitcoin.key;
    final lease = File(valueOf(writerLockPath(directory, key)));
    final movedLease = await lease.rename('${lease.path}.fixture');
    expect(await runtime.demandRetainedBalance(demand(key)), isA<Err>());
    expect(await lease.exists(), isFalse);
    await movedLease.rename(lease.path);
    final wallet = File(nativeWalletStoragePath(directory, key));
    await wallet.rename('${wallet.path}.fixture');
    expect(await runtime.demandRetainedBalance(demand(key)), isA<Err>());
    expect(await wallet.exists(), isFalse);
    expect(opens, 1);
  });

  test(
    'locking during hydration rejects work and emits no notification',
    () async {
      valueOf(await runtime.initialize());
      final candidate = demand(liquid);
      final stamp = valueOf(stores.retainedRevision(liquid)).stamp;
      final entered = Completer<void>();
      final release = Completer<void>();
      var published = false;
      var signalled = false;
      beforeHydration = () async {
        entered.complete();
        await release.future;
      };
      beforePublication = () async => published = true;
      final subscription = runtime.retainedBalanceChanges.listen(
        (_) => signalled = true,
      );
      addTearDown(subscription.cancel);
      final request = runtime.demandRetainedBalance(candidate);
      await entered.future;
      try {
        expect(await inventory.lock(), isTrue);
        expect(candidate.isCurrent, isFalse);
      } finally {
        release.complete();
      }
      expect(await request, isA<Err>());
      expect(runtime.captureBalanceDemand(liquid, () => environment), isNull);
      expect(
        runtime.readRetainedBalance(candidate.catalogue, stamp),
        isA<Err>(),
      );
      await pumpEventQueue();
      expect(published, isFalse);
      expect(signalled, isFalse);
    },
  );
}
