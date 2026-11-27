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

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('retained-balance-');
    directory = '${temp.path}/native';
    final fixture = await openFreshInventory(temp);
    inventory = fixture.inventory;
    final connections = FixtureConnections([]);
    opens = 0;
    directoryRequests = 0;
    beforeOpening = null;
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
      onStoresOpened: (_) => opens++,
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
    'cold read creates nothing; first publication needs a load, not a refresh',
    () async {
      final catalogue = capture();
      final guessed = WalletRevision(
        key: bitcoin.key,
        generation: 1,
        revision: 1,
      );
      expect(runtime.readRetainedBalance(catalogue, guessed), isA<Err>());
      expect(directoryRequests, 0);
      expect(opens, 0);
      expect(Directory(directory).existsSync(), isFalse);
      valueOf(await runtime.initialize());
      valueOf(await runtime.refreshAll());
      final revision = valueOf(await runtime.readRevision(bitcoin.key)).stamp;
      expect(runtime.readRetainedBalance(catalogue, revision), isA<Err>());
      expect(await publish(bitcoin.key), revision);
      expect(
        valueOf(runtime.readRetainedBalance(catalogue, revision)),
        BigInt.zero,
      );
      expect(opens, 1);
    },
  );

  test('native zero and nonzero balances on both chains; warm refresh without legacy reader', () async {
    final catalogue = capture();
    final btcZero = await publish(bitcoin.key);
    final liquidZero = await publish(liquid);
    expect(
      valueOf(runtime.readRetainedBalance(catalogue, btcZero)),
      BigInt.zero,
    );
    expect(
      valueOf(runtime.readRetainedBalance(catalogue, liquidZero)),
      BigInt.zero,
    );

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
    expect(runtime.readRetainedBalance(catalogue, btcZero), isA<Err>());
    expect(runtime.readRetainedBalance(catalogue, liquidZero), isA<Err>());
    valueOf(await runtime.refreshAll());
    for (var i = 0; i < 100; i++) {
      final btc = runtime.readRetainedBalance(catalogue, btcFunded);
      final lbtc = runtime.readRetainedBalance(catalogue, liquidFunded);
      if (btc is Ok && lbtc is Ok) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
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
    expect(opens, 1);
  });

  test(
    'pending at the same stamp, tombstone and recreation are refused silently',
    () async {
      final catalogue = capture();
      final stamp = await publish(bitcoin.key);
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
      final stamp = await publish(bitcoin.key);
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
      await publish(bitcoin.key);
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
      await publish(bitcoin.key);
      expect(valueOf(runtime.readRetainedBalance(renamed, stamp)), BigInt.zero);
      final closing = runtime.close();
      expect(runtime.readRetainedBalance(renamed, stamp), isA<Err>());
      valueOf(await closing);
    },
  );
}
