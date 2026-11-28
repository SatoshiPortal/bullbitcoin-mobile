import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/catalogue.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/secrets.dart'
    show SecretFailure, WalletInventory, WalletSelection;
import 'package:secrets/storage.dart';
import 'package:silent/silent.dart';
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
import '../support/overview_home_harness.dart';

class _Membership extends Fake implements WalletInventory {
  final SecretsInventory inventory;
  final gates = <Completer<void>>[];
  Completer<void>? inFlight;
  int active = 0;
  int maxActive = 0;
  int calls = 0;
  _Membership(this.inventory);

  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) async {
    active++;
    calls++;
    if (active > maxActive) maxActive = active;
    try {
      final answer = await inventory.walletsForNetwork(network);
      if (gates.isNotEmpty) {
        inFlight = gates.removeAt(0);
        await inFlight?.future;
        inFlight = null;
      }
      return answer;
    } finally {
      active--;
    }
  }
}

class _Silent extends Fake implements Silent {
  int reads = 0;
  bool hold = false;
  int amount = 1000;
  final pending = <Completer<Result<SilentWallet?, SilentFailure>>>[];
  final updates =
      StreamController<Result<SilentUpdate, SilentFailure>>.broadcast();
  @override
  Future<Result<bool, SilentFailure>> isFeatureEnabled() async =>
      const Ok(true);
  @override
  Future<Result<bool, SilentFailure>> isSetUp() async => const Ok(true);
  @override
  bool get isScanning => false;
  @override
  Future<Result<SilentWallet?, SilentFailure>> refresh() {
    reads++;
    if (!hold) {
      return Future.value(
        Ok(silentWallet(amount, network: BitcoinNetwork.testnet)),
      );
    }
    final pendingRead = Completer<Result<SilentWallet?, SilentFailure>>();
    pending.add(pendingRead);
    return pendingRead.future;
  }

  @override
  Stream<Result<SilentUpdate, SilentFailure>> watchUpdates() => updates.stream;
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 500 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for admission transition',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(BullSdk.init);

  test('real catalogue serializes admission and Home retires old Silent generations', () async {
    final temp = await Directory.systemTemp.createTemp(
      'overview-silent-admission-',
    );
    final storage = await openFreshInventory(temp);
    final inventory = storage.inventory;
    final membership = _Membership(inventory);
    final db = await createPreferencesDatabase();
    final preferences = PreferencesTesting.fromDao(PreferencesDao(db));
    valueOf(await preferences.setIsSuperuser(true));
    valueOf(await preferences.setIsDevMode(true));
    valueOf(await preferences.setEnvironment(Environment.testnet));
    final descriptor = regtestDescriptor();
    final id = '${descriptor.origin}:testnet';
    valueOf(
      await inventory.registerWallet(
        RegisteredWallet(
          id: id,
          secretFingerprint: '73c5da0a',
          masterFingerprint: '73c5da0a',
          signer: 'local',
          network: 'bitcoinTestnet',
          xpub: 'fixture',
          externalDescriptor: descriptor.externalDescriptor,
          internalDescriptor: descriptor.internalDescriptor,
          label: 'Old',
          birthday: null,
          isDefault: true,
        ),
      ),
    );
    final connections = FixtureConnections([]);
    final runtime = WalletNativeRuntime.open(
      catalog: SecretsWalletCatalog.foreground(inventory),
      reserved: const NoReservedAddresses(),
      inputReservations: NoInputReservations(),
      deleteCatalogEntry: SecretsWalletCatalog.removal(inventory),
      sync: ElectrumSync(
        connections: connections,
        documentsDirectory: () => throw StateError('Unexpected sync'),
        readRevision: (_) => throw StateError('Unexpected sync'),
      ),
      documentsDirectory: () async => '${temp.path}/native',
      freezes: MemoryFreezeStore(),
      connections: connections,
    );
    final balances = ForegroundBalanceStartup.mount(
      runtime: () => runtime,
      inventory: inventory,
      preferences: preferences,
    );
    final startup = ForegroundWalletStartup(
      initialize: runtime.initialize,
      startWatchers: () {},
      balances: balances,
    );
    final catalogue = OverviewCatalogue.mount(
      balances: balances.observation,
      inventory: membership,
    );
    final silent = _Silent();
    final sync = FakeHomeSync();
    final amountPreferences = FakeAmountDisplayPreferences();
    final started = StreamController<HomeSyncStart>.broadcast();
    final finished = StreamController<WalletKey>.broadcast();
    final electrum = StreamController<HomeElectrumOutcome>.broadcast();
    final home = OverviewHomeController(
      catalogue: CatalogueHomeSource(catalogue),
      sync: sync,
      amountDisplay: OverviewAmountDisplay(amountPreferences),
      ongoingSwaps: FakeOngoingSwaps(),
      swapServerCheck: FakeSwapServerCheck(),
      readBackupWarning: () async => false,
      readPhysicalBackup: (_) async => true,
      proxyNeedsAttention: () async => false,
      silentHome: SilentHomeObservation(silent),
      syncStarted: started.stream,
      syncFinished: finished.stream,
      electrumResults: electrum.stream,
    );
    addTearDown(() async {
      final inFlight = membership.inFlight;
      if (inFlight != null && !inFlight.isCompleted) inFlight.complete();
      for (final gate in membership.gates) {
        if (!gate.isCompleted) gate.complete();
      }
      for (final pending in silent.pending) {
        if (!pending.isCompleted) pending.complete(const Ok(null));
      }
      await home.close();
      await silent.updates.close();
      await started.close();
      await finished.close();
      await electrum.close();
      await sync.close();
      await amountPreferences.close();
      await catalogue.close();
      await startup.dispose();
      valueOf(await runtime.close());
      await preferences.close();
      await db.close();
      await inventory.close();
      await storage.admission.close();
      await temp.delete(recursive: true);
      expect(connections.attempts, 0);
    });
    final firstAdmission = Completer<void>();
    membership.gates.add(firstAdmission);
    await startup.start();
    await _until(() => membership.active == 1);
    expect(home.current.showSilentCard, isFalse);
    expect(home.current.totalSat, 0);
    expect(silent.reads, 0);
    firstAdmission.complete();
    await _until(() => home.current.totalSat == 1000);
    expect(home.current.showSilentCard, isTrue);
    expect(home.current.rows.single.selection.key.id, id);
    final observed = <OverviewHomeState>[];
    void record() => observed.add(home.current);
    home.addListener(record);

    silent.hold = true;
    silent.updates.add(Ok(SilentBalanceChanged(Sats.fromInt(9999))));
    await _until(() => silent.pending.length == 1);
    final nextAdmission = Completer<void>();
    membership.gates.add(nextAdmission);
    expect(await inventory.lock(), isTrue);
    await _until(
      () => !home.current.showSilentCard && home.current.totalSat == 0,
    );
    final retiredAt = observed.length;
    valueOf(await inventory.resumeUnprotected());
    startup.confirmUnlock();
    await _until(() => membership.active == 1);
    expect(home.current.showSilentCard, isFalse);
    expect(home.current.totalSat, 0);
    final oldCalls = membership.calls;
    final latestAdmission = Completer<void>();
    membership.gates.add(latestAdmission);
    expect(await inventory.lock(), isTrue);
    valueOf(await inventory.resumeUnprotected());
    valueOf(
      await inventory.setWalletProperties(
        id: id,
        label: 'Latest',
        birthday: null,
        isDefault: true,
      ),
    );
    startup.confirmUnlock();
    await flushEvents();
    expect(membership.calls, oldCalls);
    expect(membership.maxActive, 1);
    expect(home.current.showSilentCard, isFalse);
    expect(home.current.totalSat, 0);
    final silentReads = silent.reads;
    await home.refresh();
    await home.refresh();
    expect(silent.reads, silentReads);
    expect(membership.calls, oldCalls);
    expect(home.current.showSilentCard, isFalse);
    expect(home.current.totalSat, 0);
    nextAdmission.complete();
    await _until(() => membership.calls > oldCalls && membership.active == 1);
    expect(home.current.showSilentCard, isFalse);
    expect(home.current.totalSat, 0);
    latestAdmission.complete();
    await _until(() => silent.pending.length == 2);
    expect(home.current.showSilentCard, isFalse);
    silent.pending[1].complete(
      Ok(silentWallet(2300, network: BitcoinNetwork.testnet)),
    );
    await _until(() => home.current.totalSat == 2300);
    expect(home.current.showSilentCard, isTrue);
    expect(home.current.silent.balanceSat, 2300);
    expect(home.current.rows.single.selection.label, 'Latest');
    silent.pending[0].complete(
      Ok(silentWallet(9000, network: BitcoinNetwork.testnet)),
    );
    await flushEvents();
    expect(home.current.silent.balanceSat, 2300);
    expect(home.current.totalSat, 2300);
    expect(observed.every((state) => state.silent.balanceSat != 9000), isTrue);
    expect(
      observed
          .skip(retiredAt)
          .every((state) => state.silent.balanceSat != 1000),
      isTrue,
    );
    expect(membership.maxActive, 1);
    silent.hold = false;
    silent.amount = 3400;
    await home.refresh();
    await _until(() => home.current.totalSat == 3400);
    expect(home.current.silent.balanceSat, 3400);
    expect(home.current.showSilentCard, isTrue);
    home.removeListener(record);
  });
}
