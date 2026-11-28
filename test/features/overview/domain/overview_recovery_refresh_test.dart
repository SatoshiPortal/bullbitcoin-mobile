import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/catalogue.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:silent/silent.dart';

import '../support/overview_home_harness.dart';

import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/storage.dart';
import 'package:secrets/secrets.dart'
    show SecretFailure, SecretNotFoundFailure, WalletInventory, WalletSelection;
import 'package:startup/startup.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import '../../../../packages/secrets/test/support/open_inventory.dart';
import '../../../../packages/sync/test/support/connections.dart';
import '../../../../packages/sync/test/support/regtest_wallet.dart'
    show regtestDescriptor;
import '../../../support/preferences_database.dart';

final class _Membership extends Fake implements WalletInventory {
  final SecretsInventory inventory;
  Future<void> Function()? afterRead;
  bool failLiquid = true;
  bool failBitcoin = false;
  int reads = 0;

  _Membership(this.inventory);

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) async {
    reads++;
    if ((failLiquid && network is LiquidNetwork) ||
        (failBitcoin && network is BitcoinNetwork)) {
      return const Err(SecretNotFoundFailure());
    }
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
  late ForegroundBalanceStartup balances;
  late BitcoinWalletDescriptor bitcoin;
  late WalletKey liquid;
  late Map<String, dynamic> fixture;
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
    );
    balances = ForegroundBalanceStartup.mount(
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

  Future<void> until(bool Function() ready) async {
    for (var i = 0; i < 300 && !ready(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ready(), isTrue);
  }

  test(
    'pull refresh retries failed membership and restores omitted rows',
    () async {
      await registerBoth();
      await startup.start();
      await until(
        () => overview.snapshot.status == OverviewCatalogueStatus.partial,
      );
      expect(overview.snapshot.rows, hasLength(1));
      final h = OverviewHomeHarness();
      final home = OverviewHomeController(
        catalogue: CatalogueHomeSource(overview),
        sync: h.sync,
        amountDisplay: OverviewAmountDisplay(h.amountPreferences),
        ongoingSwaps: h.swaps,
        swapServerCheck: h.swapServer,
        readBackupWarning: () async => true,
        readPhysicalBackup: (_) async => true,
        proxyNeedsAttention: () async => false,
        silentHome: SilentHomeObservation(h.silent),
        syncStarted: h.started.stream,
        syncFinished: h.finished.stream,
        electrumResults: h.electrum.stream,
        swapActivity: h.swapActivity,
      );
      addTearDown(() async {
        await home.close();
        await h.close();
      });
      await flushEvents();
      final reads = membership.reads;
      membership.failLiquid = false;
      await home.refresh();
      await flushEvents();
      expect(
        membership.reads,
        greaterThan(reads),
        reason: 'refresh must retry membership',
      );
      expect(overview.snapshot.status, OverviewCatalogueStatus.ready);
      expect(overview.snapshot.rows, hasLength(2));
    },
  );
  test('a permanent failure does not cause an automatic retry loop', () async {
    await registerBoth();
    await startup.start();
    await until(
      () => overview.snapshot.status == OverviewCatalogueStatus.partial,
    );
    final h = OverviewHomeHarness();
    final home = OverviewHomeController(
      catalogue: CatalogueHomeSource(overview),
      sync: h.sync,
      amountDisplay: OverviewAmountDisplay(h.amountPreferences),
      ongoingSwaps: h.swaps,
      swapServerCheck: h.swapServer,
      readBackupWarning: () async => true,
      readPhysicalBackup: (_) async => true,
      proxyNeedsAttention: () async => false,
      silentHome: SilentHomeObservation(h.silent),
      syncStarted: h.started.stream,
      syncFinished: h.finished.stream,
      electrumResults: h.electrum.stream,
      swapActivity: h.swapActivity,
    );
    addTearDown(() async {
      await home.close();
      await h.close();
    });
    await flushEvents();
    final reads = membership.reads;
    await home.refresh();
    await flushEvents(30);
    expect(membership.reads, reads + 2);
    expect(overview.snapshot.status, OverviewCatalogueStatus.partial);
  });

  test('revocation retires an in-flight retry and its late response', () async {
    await registerBoth();
    await startup.start();
    await until(
      () => overview.snapshot.status == OverviewCatalogueStatus.partial,
    );
    final h = OverviewHomeHarness();
    final home = OverviewHomeController(
      catalogue: CatalogueHomeSource(overview),
      sync: h.sync,
      amountDisplay: OverviewAmountDisplay(h.amountPreferences),
      ongoingSwaps: h.swaps,
      swapServerCheck: h.swapServer,
      readBackupWarning: () async => true,
      readPhysicalBackup: (_) async => true,
      proxyNeedsAttention: () async => false,
      silentHome: SilentHomeObservation(h.silent),
      syncStarted: h.started.stream,
      syncFinished: h.finished.stream,
      electrumResults: h.electrum.stream,
      swapActivity: h.swapActivity,
    );
    addTearDown(() async {
      await home.close();
      await h.close();
    });
    final entered = Completer<void>();
    final release = Completer<void>();
    membership.failLiquid = false;
    membership.afterRead = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    await home.refresh();
    await flushEvents();
    expect(
      entered.isCompleted,
      isTrue,
      reason: 'refresh must retry membership',
    );
    balances.revokeUnlock();
    release.complete();
    await flushEvents();
    expect(overview.snapshot.status, OverviewCatalogueStatus.revoked);
    expect(overview.snapshot.rows, isEmpty);
  });
  test('late retry cannot publish into a newly admitted context', () async {
    await registerBoth();
    await startup.start();
    await until(
      () => overview.snapshot.status == OverviewCatalogueStatus.partial,
    );
    final h = OverviewHomeHarness();
    final home = OverviewHomeController(
      catalogue: CatalogueHomeSource(overview),
      sync: h.sync,
      amountDisplay: OverviewAmountDisplay(h.amountPreferences),
      ongoingSwaps: h.swaps,
      swapServerCheck: h.swapServer,
      readBackupWarning: () async => true,
      readPhysicalBackup: (_) async => true,
      proxyNeedsAttention: () async => false,
      silentHome: SilentHomeObservation(h.silent),
      syncStarted: h.started.stream,
      syncFinished: h.finished.stream,
      electrumResults: h.electrum.stream,
      swapActivity: h.swapActivity,
    );
    addTearDown(() async {
      await home.close();
      await h.close();
    });
    final entered = Completer<void>();
    final release = Completer<void>();
    membership.failLiquid = false;
    membership.afterRead = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    await home.refresh();
    await flushEvents();
    expect(
      entered.isCompleted,
      isTrue,
      reason: 'refresh must retry membership',
    );
    balances.revokeUnlock();
    balances.admitUnlock();
    await flushEvents();
    expect(overview.snapshot.rows, isEmpty);
    release.complete();
    await until(
      () => overview.snapshot.status == OverviewCatalogueStatus.ready,
    );
    expect(overview.snapshot.rows, hasLength(2));
  });
  test('pull refresh recovers an unreadable membership', () async {
    membership.failBitcoin = true;
    await registerBoth();
    await startup.start();
    await until(
      () => overview.snapshot.status == OverviewCatalogueStatus.unreadable,
    );
    expect(overview.snapshot.rows, isEmpty);
    final h = OverviewHomeHarness();
    final home = OverviewHomeController(
      catalogue: CatalogueHomeSource(overview),
      sync: h.sync,
      amountDisplay: OverviewAmountDisplay(h.amountPreferences),
      ongoingSwaps: h.swaps,
      swapServerCheck: h.swapServer,
      readBackupWarning: () async => true,
      readPhysicalBackup: (_) async => true,
      proxyNeedsAttention: () async => false,
      silentHome: SilentHomeObservation(h.silent),
      syncStarted: h.started.stream,
      syncFinished: h.finished.stream,
      electrumResults: h.electrum.stream,
      swapActivity: h.swapActivity,
    );
    addTearDown(() async {
      await home.close();
      await h.close();
    });
    final reads = membership.reads;
    membership.failBitcoin = false;
    membership.failLiquid = false;
    await home.refresh();
    await until(
      () => overview.snapshot.status == OverviewCatalogueStatus.ready,
    );
    expect(membership.reads, reads + 2);
    expect(overview.snapshot.rows, hasLength(2));
  });
}
