import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullReceiveSendButtons;
import 'package:material_ui/material_ui.dart';
import 'package:overview/catalogue.dart';
import 'package:overview/detail.dart';
import 'package:overview/overview.dart' show OverviewReceiveTarget;
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/storage.dart';
import 'package:secrets/secrets.dart'
    show SecretFailure, WalletInventory, WalletSelection, WalletSigner;
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

  test(
    'detail selection follows membership before and after receipts',
    () async {
      await registerBoth();
      final entered = Completer<void>();
      final release = Completer<void>();
      beforeHydration = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      final btc = OverviewDetailController(
        catalogue: overview,
        key: bitcoin.key,
      );
      final lbtc = OverviewDetailController(catalogue: overview, key: liquid);
      addTearDown(btc.dispose);
      addTearDown(lbtc.dispose);
      try {
        await startup.start();
        await entered.future.timeout(const Duration(seconds: 5));
        await until(() => btc.value != null && lbtc.value != null);
        final selected = btc.value;
        expect(selected?.key, bitcoin.key);
        expect(selected?.scriptType, bitcoin.scriptType);
        expect(selected?.signer, WalletSigner.local);
        expect(selected?.isDefault, isTrue);
        expect(selected?.origin, bitcoin.origin);
        expect(selected?.balanceSat, isNull);
        expect(lbtc.value?.signer, WalletSigner.remote);
        expect(lbtc.value?.label, '  raw liquid  ');
        expect(lbtc.value?.origin, liquid.id.replaceFirst(':regtest', ''));
      } finally {
        release.complete();
      }
      await until(() => btc.value?.revision != null);
      expect(btc.value?.key, bitcoin.key);
      expect(btc.value?.balanceSat, BigInt.zero);
    },
  );

  test(
    'detail readmits fresh selection after lock while retiring old selection',
    () async {
      await registerBoth();
      await startup.start();
      await until(
        () =>
            overview.snapshot.rows.isNotEmpty &&
            row(bitcoin.key).revision != null,
      );
      final controller = OverviewDetailController(
        catalogue: overview,
        key: bitcoin.key,
      );
      addTearDown(controller.dispose);
      final captured = controller.value;
      expect(captured?.isCurrent, isTrue);
      final locking = inventory.lock();
      expect(captured?.isCurrent, isFalse);
      expect(controller.value, isNull);
      expect(await locking, isTrue);
      valueOf(await inventory.resumeUnprotected());
      startup.confirmUnlock();
      await until(
        () =>
            overview.snapshot.rows.isNotEmpty &&
            row(bitcoin.key).revision != null,
      );
      await until(() => controller.value != null);
      expect(controller.value?.key, bitcoin.key);
      expect(captured?.isCurrent, isFalse);
    },
  );

  test(
    'detail follows a catalogue label replacement with a fresh selection',
    () async {
      await registerBoth();
      await startup.start();
      await until(() => overview.snapshot.rows.length == 2);
      final controller = OverviewDetailController(
        catalogue: overview,
        key: bitcoin.key,
      );
      addTearDown(controller.dispose);
      final old = controller.value;
      expect(old?.isCurrent, isTrue);
      valueOf(
        await inventory.setWalletProperties(
          id: bitcoin.key.id,
          label: 'updated',
          birthday: null,
          isDefault: true,
        ),
      );
      expect(old?.isCurrent, isFalse);
      await until(() => controller.value?.label == 'updated');
      expect(controller.value?.key, bitcoin.key);
      expect(old?.isCurrent, isFalse);
    },
  );

  test(
    'detail follows membership changes and never revives old selections',
    () async {
      await registerBoth();
      await startup.start();
      await until(() => overview.snapshot.rows.length == 2);
      final controller = OverviewDetailController(
        catalogue: overview,
        key: bitcoin.key,
      );
      addTearDown(controller.dispose);
      final first = controller.value;
      valueOf(await inventory.removeWallet(liquid.id));
      expect(first?.isCurrent, isFalse);
      await until(
        () => overview.snapshot.rows.length == 1 && controller.value != null,
      );
      final second = controller.value;
      expect(second?.key, bitcoin.key);
      expect(first?.isCurrent, isFalse);
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
      await until(
        () => overview.snapshot.rows.length == 2 && controller.value != null,
      );
      expect(second?.isCurrent, isFalse);
      final third = controller.value;
      valueOf(await inventory.removeWallet(bitcoin.key.id));
      await until(
        () => overview.snapshot.rows.length == 1 && controller.value == null,
      );
      expect(third?.isCurrent, isFalse);
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
            label: 'reimported',
            birthday: null,
            isDefault: true,
          ),
        ),
      );
      await until(() => controller.value?.label == 'reimported');
      expect(controller.value?.key, bitcoin.key);
      expect(third?.isCurrent, isFalse);
    },
  );

  testWidgets('disposed controller invalidates captured mounted callbacks', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await registerBoth();
      await startup.start();
      await until(() => overview.snapshot.rows.length == 2);
    });
    final controller = OverviewDetailController(
      catalogue: overview,
      key: bitcoin.key,
    );
    var receives = 0;
    var sends = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.values.first),
        home: OverviewSelectedWalletDetail(
          controller: controller,
          defaultBitcoinLabel: 'Default Bitcoin',
          defaultLiquidLabel: 'Default Liquid',
          unavailableMessage: 'Unavailable',
          settings: const SizedBox(),
          scopeWalletHistory: (_, child) => child,
          refreshPrice: (_) async {},
          refreshWalletHistory: (_) async {},
          balanceCard: (_, _) => const SizedBox(),
          consolidation: (_, _) => const SizedBox(),
          coinsEntry: (_, _) => const SizedBox(),
          liquidDisclosure: (_, _) => const SizedBox(),
          history: (_, _) => const SliverToBoxAdapter(),
          receiveLabel: 'Receive',
          sendLabel: 'Send',
          onReceive: (_) => receives++,
          onSend: (_) => sends++,
        ),
      ),
    );
    final selected = controller.value;
    final buttons = tester.widget<BullReceiveSendButtons>(
      find.byType(BullReceiveSendButtons),
    );
    buttons.onReceive();
    buttons.onSend?.call();
    expect(receives, 1);
    expect(sends, 1);
    controller.dispose();
    expect(selected?.isCurrent, isFalse);
    buttons.onReceive();
    buttons.onSend?.call();
    expect(receives, 1);
    expect(sends, 1);
    final replacement = OverviewDetailController(
      catalogue: overview,
      key: bitcoin.key,
    );
    addTearDown(replacement.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.values.first),
        home: OverviewSelectedWalletDetail(
          controller: replacement,
          defaultBitcoinLabel: 'Default Bitcoin',
          defaultLiquidLabel: 'Default Liquid',
          unavailableMessage: 'Unavailable',
          settings: const SizedBox(),
          scopeWalletHistory: (_, child) => child,
          refreshPrice: (_) async {},
          refreshWalletHistory: (_) async {},
          balanceCard: (_, _) => const SizedBox(),
          consolidation: (_, _) => const SizedBox(),
          coinsEntry: (_, _) => const SizedBox(),
          liquidDisclosure: (_, _) => const SizedBox(),
          history: (_, _) => const SliverToBoxAdapter(),
          receiveLabel: 'Receive',
          sendLabel: 'Send',
          onReceive: (_) => receives++,
          onSend: (_) => sends++,
        ),
      ),
    );
    buttons.onReceive();
    buttons.onSend?.call();
    expect(receives, 1);
    expect(sends, 1);
    final fresh = tester.widget<BullReceiveSendButtons>(
      find.byType(BullReceiveSendButtons),
    );
    fresh.onReceive();
    fresh.onSend?.call();
    expect(receives, 2);
    expect(sends, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'imported watch-only detail uses its registration without a receipt',
    () async {
      final key = WalletKey(
        id: 'imported([01234567/84h/1h/0h]):regtest',
        network: BitcoinNetwork.regtest,
      );
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet(
            key.id,
            network: 'bitcoinRegtest',
            signer: 'none',
            external: bitcoin.externalDescriptor,
            internal: bitcoin.internalDescriptor,
          ),
        ),
      );
      await startup.start();
      await until(
        () => overview.snapshot.rows.any((row) => row.entry.key == key),
      );
      final controller = OverviewDetailController(
        catalogue: overview,
        key: key,
      );
      addTearDown(controller.dispose);
      expect(controller.value?.key, key);
      expect(controller.value?.signer, WalletSigner.none);
      expect(controller.value?.isDefault, isFalse);
      expect(controller.value?.origin, 'imported([01234567/84h/1h/0h])');
    },
  );

  testWidgets(
    'selected detail actions use the admitted target and expire on lock',
    (tester) async {
      await tester.runAsync(() async {
        await registerBoth();
        await startup.start();
        await until(
          () =>
              overview.snapshot.rows.isNotEmpty &&
              row(bitcoin.key).revision != null,
        );
      });
      final controller = OverviewDetailController(
        catalogue: overview,
        key: bitcoin.key,
      );
      addTearDown(controller.dispose);
      OverviewReceiveTarget? received;
      WalletKey? sent;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.values.first),
          home: OverviewSelectedWalletDetail(
            controller: controller,
            defaultBitcoinLabel: 'Default Bitcoin',
            defaultLiquidLabel: 'Default Liquid',
            unavailableMessage: 'Unavailable',
            settings: const SizedBox(),
            scopeWalletHistory: (_, child) => child,
            refreshPrice: (_) async {},
            refreshWalletHistory: (_) async {},
            balanceCard: (_, wallet) => Text('balance ${wallet.balanceSat}'),
            consolidation: (_, _) => const SizedBox(),
            coinsEntry: (_, _) => const SizedBox(),
            liquidDisclosure: (_, _) => const SizedBox(),
            history: (_, _) => const SliverToBoxAdapter(),
            receiveLabel: 'Receive',
            sendLabel: 'Send',
            onReceive: (target) => received = target,
            onSend: (key) => sent = key,
          ),
        ),
      );
      expect(find.text('Default Bitcoin'), findsOneWidget);
      final buttons = tester.widget<BullReceiveSendButtons>(
        find.byType(BullReceiveSendButtons),
      );
      buttons.onReceive();
      buttons.onSend?.call();
      expect(received, (
        key: bitcoin.key,
        scriptType: bitcoin.scriptType,
        signsLocally: true,
      ));
      expect(sent, bitcoin.key);
      received = null;
      sent = null;
      await tester.runAsync(() async => inventory.lock());
      buttons.onReceive();
      buttons.onSend?.call();
      expect(received, isNull);
      expect(sent, isNull);
      await tester.pump();
      expect(find.byType(BullReceiveSendButtons), findsNothing);
    },
  );

  for (final signer in ['remote', 'none']) {
    testWidgets('imported $signer detail exposes the original receive target', (
      tester,
    ) async {
      final key = WalletKey(
        id: 'imported([01234567/84h/1h/0h]):regtest',
        network: BitcoinNetwork.regtest,
      );
      await tester.runAsync(() async {
        valueOf(
          await inventory.registerWallet(
            watchOnlyWallet(
              key.id,
              network: 'bitcoinRegtest',
              signer: signer,
              external: bitcoin.externalDescriptor,
              internal: bitcoin.internalDescriptor,
            ),
          ),
        );
        await startup.start();
        await until(
          () => overview.snapshot.rows.any((row) => row.entry.key == key),
        );
      });
      final controller = OverviewDetailController(
        catalogue: overview,
        key: key,
      );
      addTearDown(controller.dispose);
      OverviewReceiveTarget? received;
      WalletKey? sent;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.values.first),
          home: OverviewSelectedWalletDetail(
            controller: controller,
            defaultBitcoinLabel: 'Default Bitcoin',
            defaultLiquidLabel: 'Default Liquid',
            unavailableMessage: 'Unavailable',
            settings: const SizedBox(),
            scopeWalletHistory: (_, child) => child,
            refreshPrice: (_) async {},
            refreshWalletHistory: (_) async {},
            balanceCard: (_, _) => const SizedBox(),
            consolidation: (_, _) => const SizedBox(),
            coinsEntry: (_, _) => const SizedBox(),
            liquidDisclosure: (_, _) => const SizedBox(),
            history: (_, _) => const SliverToBoxAdapter(),
            receiveLabel: 'Receive',
            sendLabel: 'Send',
            onReceive: (target) => received = target,
            onSend: (key) => sent = key,
          ),
        ),
      );
      expect(find.text('imported([01234567/84h/1h/0h])'), findsOneWidget);
      final buttons = tester.widget<BullReceiveSendButtons>(
        find.byType(BullReceiveSendButtons),
      );
      buttons.onReceive();
      expect(received, (
        key: key,
        scriptType: ScriptType.bip84,
        signsLocally: false,
      ));
      if (signer == 'none') {
        expect(buttons.onSend, isNull);
      } else {
        buttons.onSend?.call();
        expect(sent, key);
      }
    });
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
    final detail = OverviewDetailController(
      catalogue: overview,
      key: bitcoin.key,
    );
    addTearDown(detail.dispose);
    final membership = detail.value;
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
    await until(() => detail.value?.revision == recreated);
    expect(membership?.isCurrent, isTrue);
    expect(detail.value?.key, bitcoin.key);
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
