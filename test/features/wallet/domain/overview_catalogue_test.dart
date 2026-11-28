import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/catalogue.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/storage.dart';
import 'package:secrets/secrets.dart'
    show SecretFailure, WalletInventory, WalletSelection;
import 'package:sqlite3/sqlite3.dart';
import 'package:startup/startup.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import '../../../../packages/secrets/test/support/open_inventory.dart';
import '../../../../packages/sync/test/support/connections.dart';
import '../../../../packages/sync/test/support/native_funding.dart';
import '../../../../packages/sync/test/support/regtest_wallet.dart'
    show regtestDescriptor;
import '../../../../packages/sync/test/support/second_revision_connection.dart';
import '../../../support/preferences_database.dart';

final class _Membership extends Fake implements WalletInventory {
  final SecretsInventory inventory;
  Future<void> Function()? afterRead;

  _Membership(this.inventory);

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) async {
    final result = await inventory.walletsForNetwork(network);
    await afterRead?.call();
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(BullSdk.init);
  late Directory temp;
  late String directory;
  late SecretsInventory inventory;
  late Preferences preferences;
  late WalletNativeRuntime native;
  late ForegroundWalletStartup startup;
  late OverviewCatalogue overview;
  late BitcoinWalletDescriptor bitcoin;
  late WalletKey liquid;
  late Map<String, dynamic> fixture;
  late Future<void> Function()? beforeHydration;
  late int opens;
  late int hydrations;
  late bool refuseInitialization;
  late _Membership membership;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('overview-receipts-');
    directory = '${temp.path}/native';
    final storage = await openFreshInventory(temp);
    inventory = storage.inventory;
    membership = _Membership(inventory);
    final database = await createPreferencesDatabase();
    preferences = PreferencesTesting.fromDao(PreferencesDao(database));
    valueOf(await preferences.setIsSuperuser(true));
    valueOf(await preferences.setIsDevMode(true));
    valueOf(await preferences.setEnvironment(Environment.regtest));
    beforeHydration = null;
    opens = 0;
    hydrations = 0;
    refuseInitialization = false;
    final connections = FixtureConnections([]);
    native = WalletNativeRuntime.open(
      catalog: SecretsWalletCatalog.foreground(inventory),
      reserved: const NoReservedAddresses(),
      inputReservations: NoInputReservations(),
      deleteCatalogEntry: SecretsWalletCatalog.removal(inventory),
      sync: ElectrumSync(
        connections: connections,
        documentsDirectory: () => throw StateError('Unexpected sync'),
        readRevision: (_) => throw StateError('Unexpected sync'),
      ),
      documentsDirectory: () async => directory,
      freezes: MemoryFreezeStore(),
      connections: connections,
      onStoresOpened: (_) => opens++,
      beforeBalanceHydration: () async {
        hydrations++;
        await beforeHydration?.call();
      },
    );
    final balances = ForegroundBalanceStartup.mount(
      runtime: () => native,
      inventory: inventory,
      preferences: preferences,
    );
    startup = ForegroundWalletStartup(
      initialize: () async => refuseInitialization
          ? const Err(SyncStorageFailure())
          : await native.initialize(),
      startWatchers: () {},
      balances: balances,
    );
    overview = OverviewCatalogue.mount(
      balances: balances.observation,
      inventory: membership,
    );
    addTearDown(() async {
      await overview.close();
      await startup.dispose();
      valueOf(await native.close());
      await preferences.close();
      await database.close();
      await inventory.close();
      await storage.admission.close();
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
    fixture = jsonDecode(
      await File('packages/sync/test/fixtures/retained_liquid_deposit.json')
          .readAsString(),
    ) as Map<String, dynamic>;
  });

  Future<void> registerBoth() async {
    valueOf(
      await inventory.registerWallet(
        RegisteredWallet(
          id: bitcoin.key.id,
          secretFingerprint: '73c5da0a',
          masterFingerprint: '73c5da0a',
          signer: 'local',
          network: 'bitcoinRegtest',
          xpub: 'fixture',
          externalDescriptor: bitcoin.externalDescriptor,
          internalDescriptor: bitcoin.internalDescriptor,
          label: null,
          birthday: null,
          isDefault: true,
        ),
      ),
    );
    valueOf(
      await inventory.registerWallet(
        watchOnlyWallet(
          liquid.id,
          network: 'liquidRegtest',
          external: fixture['descriptor'] as String,
          label: '  raw liquid  ',
          isDefault: true,
        ),
      ),
    );
  }

  OverviewCatalogueRow row(WalletKey key) =>
      overview.snapshot.rows.singleWhere((row) => row.entry.key == key);

  Future<void> until(bool Function() ready) async {
    for (var i = 0; i < 300 && !ready(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ready(), isTrue);
  }

  Future<void> funded(SecondRevisionConnection store) async {
    store.begin(bitcoin.key, WriteIntent.sync);
    fundBitcoinNativeStore(directory, bitcoin);
    store.finish(bitcoin.key);
    store.begin(liquid, WriteIntent.sync);
    final update = File(
      '${nativeWalletStoragePath(directory, liquid)}/${fixture['path']}',
    );
    await update.parent.create(recursive: true);
    await update.writeAsBytes(base64Decode(fixture['update'] as String));
    store.finish(liquid);
  }

  for (final preload in [false, true]) {
    test(
      'membership precedes first ${preload ? 'funded' : 'zero'} receipts on both chains',
      () async {
        await registerBoth();
        if (preload) {
          valueOf(await native.initialize());
          final store = SecondRevisionConnection(revisionStorePath(directory));
          try {
            await funded(store);
          } finally {
            store.close();
          }
        }
        final entered = Completer<void>();
        final release = Completer<void>();
        beforeHydration = () async {
          if (!entered.isCompleted) entered.complete();
          await release.future;
        };
        expect(overview.snapshot.status, OverviewCatalogueStatus.revoked);
        try {
          await startup.start();
          await entered.future.timeout(const Duration(seconds: 5));
          await until(
            () => overview.snapshot.status == OverviewCatalogueStatus.ready,
          );
          expect(overview.snapshot.rows.map((row) => row.entry.key), [
            bitcoin.key,
            liquid,
          ]);
          expect(row(bitcoin.key).entry.label, isNull);
          expect(row(liquid).entry.label, '  raw liquid  ');
          expect(row(bitcoin.key).revision, isNull);
          expect(row(liquid).balanceSat, isNull);
          expect(overview.selectLocal(row(bitcoin.key)), isNull);
        } finally {
          release.complete();
        }
        await until(
          () => overview.snapshot.rows.every((row) => row.balanceSat != null),
        );
        expect(row(bitcoin.key).balanceSat, BigInt.from(preload ? 54321 : 0));
        expect(row(liquid).balanceSat, BigInt.from(preload ? 12345 : 0));
        expect(overview.selectLocal(row(bitcoin.key)), (
          key: bitcoin.key,
          label: null,
          isDefault: true,
        ));
        expect(overview.selectLocal(row(liquid)), isNull);
        expect(opens, 1);
        expect(hydrations, 2);
      },
    );
  }

  test('same-stamp pending on another connection refuses old money and tap before wakeup', () async {
    await registerBoth();
    await startup.start();
    await until(
      () =>
          overview.snapshot.rows.length == 2 &&
          row(bitcoin.key).revision != null,
    );
    final old = row(bitcoin.key);
    final witness = old.revision;
    final path = revisionStorePath(directory);
    final second = SecondRevisionConnection(path);
    addTearDown(second.close);
    final raw = sqlite3.open(path, mode: OpenMode.readWrite);
    addTearDown(raw.close);
    second.begin(bitcoin.key, WriteIntent.sync);
    expect(second.stamp(bitcoin.key), witness);
    expect(old.balanceSat, isNull);
    expect(overview.selectLocal(old), isNull);
    expect(overview.snapshot.rows, hasLength(2));
    valueOf(await native.refresh(bitcoin.key));
    await pumpEventQueue();
    // Undo only the simulated pending intent, retaining the entire stamp.
    raw.execute(
      "UPDATE revisions SET lifecycle='active', intent=NULL, candidate=NULL WHERE wallet=?",
      [bitcoin.key.id],
    );
    expect(second.stamp(bitcoin.key), witness);
    valueOf(await native.refresh(bitcoin.key));
    await until(() => row(bitcoin.key).revision != null);
    expect(overview.selectLocal(old), isNull);
    expect(overview.selectLocal(row(bitcoin.key)), isNotNull);
    final beforeDelete = row(bitcoin.key);
    second.begin(bitcoin.key, WriteIntent.delete);
    second.finish(bitcoin.key);
    expect(beforeDelete.balanceSat, isNull);
    expect(overview.selectLocal(beforeDelete), isNull);
    valueOf(await native.refresh(bitcoin.key));
    second.begin(bitcoin.key, WriteIntent.create);
    final recreated = second.finish(bitcoin.key, descriptor: bitcoin);
    expect(recreated.generation, isNot(witness?.generation));
    valueOf(await native.refresh(bitcoin.key));
    await until(() => row(bitcoin.key).revision == recreated);
    expect(overview.selectLocal(beforeDelete), isNull);
    expect(overview.snapshot.rows, hasLength(2));

    final homonym = WalletKey(
      id: bitcoin.key.id,
      network: LiquidNetwork.regtest,
    );
    second.begin(homonym, WriteIntent.create);
    second.finish(homonym);
    final beforeHomonym = row(bitcoin.key);
    final count = hydrations;
    valueOf(await native.refresh(homonym));
    await pumpEventQueue();
    expect(overview.snapshot.rows.map((row) => row.entry.key), [
      bitcoin.key,
      liquid,
    ]);
    expect(beforeHomonym.revision, recreated);
    expect(hydrations, count);
  });

  test(
    'catalogue commit, environment A-B-A and grant changes retire old rows',
    () async {
      await registerBoth();
      await startup.start();
      await until(
        () =>
            overview.snapshot.rows.length == 2 &&
            row(bitcoin.key).revision != null,
      );
      final old = row(bitcoin.key);
      final revision = old.revision;
      valueOf(
        await inventory.setWalletProperties(
          id: bitcoin.key.id,
          label: '  raw rename  ',
          birthday: null,
          isDefault: true,
        ),
      );
      expect(old.balanceSat, isNull);
      expect(overview.selectLocal(old), isNull);
      await until(
        () =>
            overview.snapshot.rows.isNotEmpty &&
            row(bitcoin.key).revision != null,
      );
      final renamed = row(bitcoin.key);
      expect(renamed.revision, revision);
      expect(renamed.entry.label, '  raw rename  ');

      final leave = preferences.setEnvironment(Environment.testnet);
      expect(renamed.balanceSat, isNull);
      expect(overview.selectLocal(renamed), isNull);
      valueOf(await leave);
      await until(
        () => overview.snapshot.status == OverviewCatalogueStatus.empty,
      );
      valueOf(await preferences.setEnvironment(Environment.regtest));
      await until(
        () =>
            overview.snapshot.rows.isNotEmpty &&
            row(bitcoin.key).revision != null,
      );
      final returned = row(bitcoin.key);
      expect(returned.revision, revision);
      expect(renamed.balanceSat, isNull);
      final locking = inventory.lock();
      expect(overview.snapshot.rows, isEmpty);
      expect(returned.balanceSat, isNull);
      expect(overview.selectLocal(returned), isNull);
      expect(await locking, isTrue);
      valueOf(await inventory.resumeUnprotected());
      startup.confirmUnlock();
      await until(
        () =>
            overview.snapshot.rows.isNotEmpty &&
            row(bitcoin.key).revision != null,
      );
      expect(overview.selectLocal(returned), isNull);
      expect(overview.selectLocal(row(bitcoin.key)), isNotNull);
    },
  );

  test('grant replacement discards a suspended membership read', () async {
    await registerBoth();
    final entered = Completer<void>();
    final release = Completer<void>();
    membership.afterRead = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    try {
      await startup.start();
      await entered.future.timeout(const Duration(seconds: 5));
      final locking = inventory.lock();
      expect(overview.snapshot.status, OverviewCatalogueStatus.revoked);
      expect(overview.snapshot.rows, isEmpty);
      expect(await locking, isTrue);
      valueOf(await inventory.resumeUnprotected());
      startup.confirmUnlock();
      valueOf(
        await inventory.setWalletProperties(
          id: bitcoin.key.id,
          label: 'replacement',
          birthday: null,
          isDefault: true,
        ),
      );
    } finally {
      membership.afterRead = null;
      release.complete();
    }
    await until(
      () => overview.snapshot.status == OverviewCatalogueStatus.ready,
    );
    expect(row(bitcoin.key).entry.label, 'replacement');
  });

  test(
    'native initialization failure does not remove Secrets membership',
    () async {
      await registerBoth();
      refuseInitialization = true;
      await startup.start();
      await until(
        () => overview.snapshot.status == OverviewCatalogueStatus.ready,
      );
      expect(overview.snapshot.rows.map((row) => row.entry.key), [
        bitcoin.key,
        liquid,
      ]);
      expect(
        overview.snapshot.rows.every((row) => row.revision == null),
        isTrue,
      );
      expect(opens, 0);
      expect(hydrations, 0);
    },
  );

  test('stable default ranks and globally interleaved imports', () async {
    await startup.start();
    await until(
      () => overview.snapshot.status == OverviewCatalogueStatus.empty,
    );
    final ids = <String>[];
    for (final (prefix, isLiquid, isDefault) in [
      ('q', true, true),
      ('z', false, false),
      ('m', true, false),
      ('p', false, true),
      ('b', false, false),
      ('a', false, true),
    ]) {
      final id = '${isLiquid ? "el" : ""}$prefix([73c5da0a/84h/1h/0h]):regtest';
      ids.add(id);
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet(
            id,
            network: isLiquid ? 'liquidRegtest' : 'bitcoinRegtest',
            external: isLiquid
                ? fixture['descriptor'] as String
                : bitcoin.externalDescriptor,
            internal: bitcoin.internalDescriptor,
            isDefault: isDefault,
          ),
        ),
      );
    }
    await until(() => overview.snapshot.rows.length == ids.length);
    expect(overview.snapshot.rows.map((row) => row.entry.key.id), [
      ids[5],
      ids[3],
      ids[0],
      ids[4],
      ids[2],
      ids[1],
    ]);
    expect(overview.snapshot.rows.every((row) => row.revision == null), isTrue);
  });

  test(
    'complete empty, partial with no rows, and unreadable are distinct',
    () async {
      await startup.start();
      await until(
        () => overview.snapshot.status == OverviewCatalogueStatus.empty,
      );
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet('bad:regtest', network: 'bitcoinRegtest'),
        ),
      );
      await until(
        () => overview.snapshot.status == OverviewCatalogueStatus.partial,
      );
      expect(overview.snapshot.rows, isEmpty);
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet('el-bad:regtest', network: 'liquidRegtest'),
        ),
      );
      await until(
        () => overview.snapshot.status == OverviewCatalogueStatus.unreadable,
      );
      expect(overview.snapshot.rows, isEmpty);
      expect(hydrations, 0);
    },
  );
}
