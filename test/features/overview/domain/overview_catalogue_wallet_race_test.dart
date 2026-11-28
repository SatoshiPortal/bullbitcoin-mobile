import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/catalogue.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/storage.dart';
import 'package:silent/silent.dart';
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
import '../support/overview_home_harness.dart'
    show
        FakeAmountDisplayPreferences,
        FakeHomeSync,
        FakeOngoingSwaps,
        FakeSilent,
        FakeSwapServerCheck,
        flushEvents;

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

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('overview-races-');
    directory = '${temp.path}/native';
    final storage = await openFreshInventory(temp);
    inventory = storage.inventory;
    final database = await createPreferencesDatabase();
    preferences = PreferencesTesting.fromDao(PreferencesDao(database));
    valueOf(await preferences.setIsSuperuser(true));
    valueOf(await preferences.setIsDevMode(true));
    valueOf(await preferences.setEnvironment(Environment.regtest));
    beforeHydration = null;
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
      beforeBalanceHydration: () async {
        await beforeHydration?.call();
      },
    );
    final balances = ForegroundBalanceStartup.mount(
      runtime: () => native,
      inventory: inventory,
      preferences: preferences,
    );
    startup = ForegroundWalletStartup(
      initialize: native.initialize,
      startWatchers: () {},
      balances: balances,
    );
    overview = OverviewCatalogue.mount(
      balances: balances.observation,
      inventory: inventory,
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

  test(
    'receipts for both chains keep the catalogue order and the Home total',
    () async {
      await registerBoth();
      valueOf(await native.initialize());
      final store = SecondRevisionConnection(revisionStorePath(directory));
      try {
        await funded(store);
      } finally {
        store.close();
      }

      await startup.start();
      await until(
        () =>
            overview.snapshot.rows.length == 2 &&
            overview.snapshot.rows.every((row) => row.balanceSat != null),
      );
      expect(overview.snapshot.rows.map((row) => row.entry.key), [
        bitcoin.key,
        liquid,
      ]);
      expect(row(bitcoin.key).balanceSat, BigInt.from(54321));
      expect(row(liquid).balanceSat, BigInt.from(12345));

      final sync = FakeHomeSync();
      final swaps = FakeOngoingSwaps();
      final server = FakeSwapServerCheck();
      final silent = FakeSilent();
      final amount = FakeAmountDisplayPreferences();
      final started = StreamController<HomeSyncStart>.broadcast();
      final finished = StreamController<WalletKey>.broadcast();
      final electrum = StreamController<HomeElectrumOutcome>.broadcast();
      final home = OverviewHomeController(
        catalogue: CatalogueHomeSource(overview),
        sync: sync,
        amountDisplay: OverviewAmountDisplay(amount),
        ongoingSwaps: swaps,
        swapServerCheck: server,
        readBackupWarning: () async => null,
        readPhysicalBackup: (_) async => true,
        proxyNeedsAttention: () async => false,
        silentHome: SilentHomeObservation(silent),
        syncStarted: started.stream,
        syncFinished: finished.stream,
        electrumResults: electrum.stream,
      );
      addTearDown(() async {
        await home.close();
        await started.close();
        await finished.close();
        await electrum.close();
        await amount.close();
        await sync.close();
      });
      await flushEvents();
      expect(home.current.rows.map((row) => row.selection.key), [
        bitcoin.key,
        liquid,
      ]);
      expect(home.current.totalSat, 66666);

      // Both receipts are re-read independently, the lower-ranked chain first.
      // Neither receipt lands in another wallet's row, and Home keeps the
      // admitted order and the exact sum.
      valueOf(await native.refresh(liquid));
      valueOf(await native.refresh(bitcoin.key));
      await until(
        () => home.current.rows.length == 2 && home.current.totalSat != null,
      );
      expect(home.current.rows.map((row) => row.selection.key), [
        bitcoin.key,
        liquid,
      ]);
      expect(home.current.totalSat, 66666);
      expect(row(bitcoin.key).balanceSat, BigInt.from(54321));
      expect(row(liquid).balanceSat, BigInt.from(12345));
    },
  );

  test(
    'a wallet removed while its receipt is still pending never returns',
    () async {
      await registerBoth();
      final entered = Completer<void>();
      final release = Completer<void>();
      beforeHydration = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      try {
        await startup.start();
        await entered.future.timeout(const Duration(seconds: 5));
        await until(
          () =>
              overview.snapshot.status == OverviewCatalogueStatus.ready &&
              overview.snapshot.rows.length == 2,
        );
        // Membership is admitted before any receipt exists.
        expect(
          overview.snapshot.rows.every((row) => row.balanceSat == null),
          isTrue,
        );

        valueOf(await inventory.removeWallet(liquid.id));
        await flushEvents();
        // A removal retires the old context at once: the removed row is gone
        // even though its receipt read is still pending.
        expect(
          overview.snapshot.rows.any((row) => row.entry.key == liquid),
          isFalse,
        );
      } finally {
        beforeHydration = null;
        release.complete();
      }

      // The pending read now settles. It must install the remaining wallet and
      // never bring the removed one back.
      await until(() => overview.snapshot.rows.length == 1);
      expect(overview.snapshot.rows.single.entry.key, bitcoin.key);
      valueOf(await native.refresh(bitcoin.key));
      await until(() => row(bitcoin.key).revision != null);
      for (var i = 0; i < 25; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          overview.snapshot.rows.map((row) => row.entry.key),
          [bitcoin.key],
          reason: 'the removed wallet came back after its pending read settled',
        );
      }
    },
  );
}
