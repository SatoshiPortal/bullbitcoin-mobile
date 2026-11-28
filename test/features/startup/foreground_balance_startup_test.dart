import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:access/setup.dart';
import 'package:access/testing.dart';
import 'package:bb_mobile/app.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/storage.dart';
import 'package:startup/startup.dart';
import 'package:startup/testing.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import '../../../packages/secrets/test/support/open_inventory.dart';
import '../../../packages/sync/test/support/connections.dart';
import '../../../packages/sync/test/support/regtest_wallet.dart'
    show regtestDescriptor;
import '../../support/preferences_database.dart';

final class _StartupBloc extends Mock implements AppStartupBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SecretsInventory inventory;
  late WalletNativeRuntime native;
  late ForegroundWalletStartup startup;
  late Completer<Result<void, SyncFailure>> initializing;
  late StreamController<bool> transitions;
  late StreamController<WalletRevisionState> revisions;
  late List<RetainedBalanceDemand> requested;
  late List<WalletCatalogueStamp> selections;
  late NetworkEnv? network;
  late bool changing;
  late Future<void> Function()? beforeSelection;
  late Future<void> Function()? beforeResult;
  late int initializations;
  late int started;
  late bool allowNativeOpen;
  late int nativeOpens;
  final btc = WalletKey(id: 'btc', network: BitcoinNetwork.regtest);
  final liquid = WalletKey(id: 'liquid', network: LiquidNetwork.regtest);
  final testnet = WalletKey(id: 'btc', network: BitcoinNetwork.testnet);
  final outside = WalletKey(id: 'outside', network: BitcoinNetwork.regtest);

  WalletRevision stamp(WalletKey key, [int revision = 1]) =>
      WalletRevision(key: key, generation: 1, revision: revision);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('balance-startup-');
    final fixture = await openFreshInventory(directory);
    inventory = fixture.inventory;
    transitions = StreamController<bool>.broadcast(sync: true);
    revisions = StreamController<WalletRevisionState>.broadcast(sync: true);
    requested = [];
    selections = [];
    changing = false;
    network = NetworkEnv.regtest;
    beforeSelection = null;
    beforeResult = null;
    initializations = 0;
    started = 0;
    allowNativeOpen = false;
    nativeOpens = 0;
    initializing = Completer<Result<void, SyncFailure>>();
    final connections = FixtureConnections([]);
    native = WalletNativeRuntime.open(
      catalog: SecretsWalletCatalog.foreground(inventory),
      reserved: const NoReservedAddresses(),
      inputReservations: NoInputReservations(),
      deleteCatalogEntry: (_) => throw StateError('Unexpected delete'),
      sync: ElectrumSync(
        connections: connections,
        documentsDirectory: () => throw StateError('Unexpected sync'),
        readRevision: (_) => throw StateError('Unexpected sync'),
      ),
      documentsDirectory: () async {
        if (!allowNativeOpen) throw StateError('Unexpected runtime open');
        return '${directory.path}/native';
      },
      freezes: MemoryFreezeStore(),
      connections: connections,
      onStoresOpened: (_) => nativeOpens++,
    );
    startup = ForegroundWalletStartup(
      initialize: () {
        initializations++;
        return initializing.future;
      },
      startWatchers: () => started++,
      balances: ForegroundBalanceStartup.testing(
        catalogue: inventory.walletCatalogue,
        session: inventory.foregroundSession,
        transitions: transitions.stream,
        environmentChanging: () => changing,
        isUnprotected: () async => (await inventory.isProtected()).fold(
          (value) => !value,
          (_) => false,
        ),
        readEnvironment: () async => network,
        select: (catalogue) async {
          selections.add(catalogue);
          await beforeSelection?.call();
          return Ok([btc, liquid, testnet]);
        },
        revisions: () => revisions.stream,
        capture: native.captureBalanceDemand,
        demand: (demand) async {
          requested.add(demand);
          await beforeResult?.call();
          return Ok(stamp(demand.key));
        },
      ),
    );
    addTearDown(() async {
      await startup.dispose();
      valueOf(await native.close());
      await transitions.close();
      await revisions.close();
      await inventory.close();
      await fixture.admission.close();
      await directory.delete(recursive: true);
    });
  });

  test(
    'production mount retains both cold native balances off shell',
    () async {
      await BullSdk.init();
      allowNativeOpen = true;
      final vector = regtestDescriptor();
      final key = WalletKey(
        id: '${vector.origin}:regtest',
        network: BitcoinNetwork.regtest,
      );
      final liquidKey = WalletKey(
        id: 'elwpkh([73c5da0a/84h/1h/0h]):regtest',
        network: LiquidNetwork.regtest,
      );
      final vectorJson = jsonDecode(
        await File('packages/sync/test/fixtures/retained_liquid_deposit.json')
            .readAsString(),
      ) as Map<String, dynamic>;
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet(
            key.id,
            network: 'bitcoinRegtest',
            external: vector.externalDescriptor,
            internal: vector.internalDescriptor,
          ),
        ),
      );
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet(
            liquidKey.id,
            network: 'liquidRegtest',
            external: vectorJson['descriptor'] as String,
          ),
        ),
      );
      final database = await createPreferencesDatabase();
      final preferences = PreferencesTesting.fromDao(PreferencesDao(database));
      addTearDown(database.close);
      addTearDown(preferences.close);
      valueOf(await preferences.setIsSuperuser(true));
      valueOf(await preferences.setIsDevMode(true));
      valueOf(await preferences.setEnvironment(Environment.regtest));
      final mounted = ForegroundWalletStartup(
        initialize: native.initialize,
        startWatchers: () => started++,
        balances: ForegroundBalanceStartup.mount(
          runtime: () => native,
          inventory: inventory,
          preferences: preferences,
        ),
      );
      addTearDown(mounted.dispose);
      final first = native.retainedBalanceChanges.take(2).drain<void>();
      await mounted.start();
      await first.timeout(const Duration(seconds: 5));
      expect(started, 1);
      for (final requested in [key, liquidKey]) {
        final stamp = valueOf(await native.readRevision(requested)).stamp;
        final catalogue = inventory.walletCatalogue.capture();
        if (catalogue == null) throw StateError('Expected a catalogue');
        expect(
          valueOf(native.readRetainedBalance(catalogue, stamp)),
          BigInt.zero,
        );
      }
      expect(nativeOpens, 1);
    },
  );

  test(
    'no-PIN startup returns while its one admitted selection waits',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      beforeSelection = () async {
        entered.complete();
        await release.future;
      };
      final shell = startup.start();
      expect(startup.start(), same(shell));
      expect(requested, isEmpty);
      initializing.complete(const Ok(null));
      try {
        await shell;
        await entered.future;
        expect(started, 1);
        expect(initializations, 1);
        expect(requested, isEmpty);
      } finally {
        beforeSelection = null;
        release.complete();
      }
      await pumpEventQueue();
      expect(requested.map((value) => value.key), [btc, liquid]);
    },
  );

  test(
    'initialization failure leaves demand closed but the shell advances',
    () async {
      final shell = startup.start();
      initializing.complete(const Err(SyncStorageFailure()));
      await shell;
      startup.confirmUnlock();
      changing = true;
      transitions.add(true);
      changing = false;
      transitions.add(false);
      await pumpEventQueue();
      expect(started, 1);
      expect(initializations, 1);
      expect(selections, isEmpty);
      expect(requested, isEmpty);
    },
  );

  test(
    'pending to active at equal stamp renews only its selected key',
    () async {
      initializing.complete(const Ok(null));
      await startup.start();
      await pumpEventQueue();
      expect(requested.map((value) => value.key), [btc, liquid]);
      requested.clear();
      void revision(
        WalletKey key,
        WalletLifecycle lifecycle, [
        int number = 1,
      ]) => revisions.add(
        WalletRevisionState(stamp: stamp(key, number), lifecycle: lifecycle),
      );
      revision(btc, WalletLifecycle.active);
      revision(outside, WalletLifecycle.active);
      revision(testnet, WalletLifecycle.active);
      await pumpEventQueue();
      expect(requested, isEmpty);
      revision(btc, WalletLifecycle.pendingWrite);
      revision(btc, WalletLifecycle.active);
      revision(btc, WalletLifecycle.active);
      await pumpEventQueue();
      expect(requested.map((value) => value.key), [btc]);
      revision(liquid, WalletLifecycle.active, 2);
      revision(liquid, WalletLifecycle.active, 3);
      await pumpEventQueue();
      expect(requested.map((value) => value.key), [btc, liquid]);
      expect(selections, hasLength(1));
    },
  );

  test(
    'replacement captured during a drain never follows the next grant',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      beforeResult = () async {
        entered.complete();
        await release.future;
      };
      initializing.complete(const Ok(null));
      await startup.start();
      await entered.future;
      final original = requested.single;
      try {
        expect(await inventory.lock(), isTrue);
        valueOf(await inventory.resumeUnprotected());
        startup.confirmUnlock();
        expect(await inventory.lock(), isTrue);
        valueOf(await inventory.resumeUnprotected()); // Not confirmed.
      } finally {
        beforeResult = null;
        release.complete();
      }
      await pumpEventQueue();
      expect(original.isCurrent, isFalse);
      expect(requested, [original]);
      startup.confirmUnlock();
      await pumpEventQueue();
      expect(requested.skip(1).map((value) => value.key), [btc, liquid]);
      expect(
        requested.last.catalogue.grant,
        isNot(same(original.catalogue.grant)),
      );
    },
  );

  test(
    'warm no-PIN completion can precede its verified automatic reopen',
    () async {
      initializing.complete(const Ok(null));
      await startup.start();
      await pumpEventQueue();
      expect(requested, hasLength(2));
      expect(await inventory.lock(), isTrue);
      startup.confirmUnlock();
      await pumpEventQueue();
      expect(requested, hasLength(2));
      valueOf(await inventory.resumeUnprotected());
      await pumpEventQueue();
      expect(requested.skip(2).map((value) => value.key), [btc, liquid]);
      expect(initializations, 1);
    },
  );

  test('catalogue commits and A-B-A retire a suspended selection', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    beforeSelection = () async {
      entered.complete();
      await release.future;
    };
    initializing.complete(const Ok(null));
    await startup.start();
    await entered.future;
    final initial = selections.single;
    try {
      valueOf(await inventory.registerWallet(watchOnlyWallet('unrelated')));
      changing = true;
      transitions.add(true);
      network = NetworkEnv.testnet;
      changing = false;
      transitions.add(false);
      changing = true;
      transitions.add(true);
      network = NetworkEnv.regtest;
      changing = false;
      transitions.add(false);
    } finally {
      beforeSelection = null;
      release.complete();
    }
    await pumpEventQueue();
    expect(selections, hasLength(2));
    expect(selections.last.generation, greaterThan(initial.generation));
    expect(requested.map((value) => value.key), [btc, liquid]);
    expect(requested.first.environment.epoch, 2);
    valueOf(
      await inventory.setWalletProperties(
        id: 'unrelated',
        label: 'renamed',
        birthday: null,
        isDefault: false,
      ),
    );
    await pumpEventQueue();
    expect(requested.skip(2).map((value) => value.key), [btc, liquid]);
  });

  test('dispose retires then drains without closing Sync', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    beforeResult = () async {
      entered.complete();
      await release.future;
    };
    initializing.complete(const Ok(null));
    await startup.start();
    await entered.future;
    var drained = false;
    final disposing = startup.dispose();
    expect(startup.dispose(), same(disposing));
    final observed = disposing.then((_) => drained = true);
    try {
      await pumpEventQueue();
      expect(drained, isFalse);
      expect(requested.single.isCurrent, isFalse);
    } finally {
      release.complete();
    }
    await observed;
    expect(requested, hasLength(1));
    expect(
      native.captureBalanceDemand(
        btc,
        () => (environment: NetworkEnv.regtest, epoch: 0),
      ),
      isNotNull,
    );
  });

  testWidgets('real PIN gate then warm unlock returns to a non-Home URI', (
    tester,
  ) async {
    final services = GetIt.asNewInstance();
    late AccessFeature feature;
    await tester.runAsync(() async {
      valueOf(await inventory.setCredential('4315'));
      expect(await inventory.lock(), isTrue);
      feature = AccessFeature.mount(
        services: services,
        inventory: inventory,
        onUnlocked: (_) => fail('Warm override must bypass default route'),
        onBackUp: (_) async {},
      );
    });
    addTearDown(services.reset);
    final state = _StartupBloc();
    when(() => state.state).thenReturn(
      const AppStartupState.success(
        isPinCodeSet: true,
        hasDefaultWallets: true,
      ),
    );
    when(() => state.stream).thenAnswer((_) => const Stream.empty());
    final localizations = [
      AccessLocalizations.delegate,
      bullUiLocalizationsDelegate,
      ...GlobalMaterialLocalizations.delegates,
    ];
    final theme = AppTheme.themeData(AppThemeType.light);
    Future<void> until(bool Function() ready) async {
      // Pump both the widget's fake clock and the real owner IO. The PIN gate
      // derives Argon2id in an isolate, so the wait is bounded by real elapsed
      // time: a fixed pump count expires on a loaded runner while a
      // verification is still running and then fails on a healthy unlock.
      final elapsed = Stopwatch()..start();
      while (!ready() && elapsed.elapsed < const Duration(seconds: 30)) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(ready(), isTrue);
    }

    Future<void> pin(String digits) async {
      final bloc = tester
          .element(find.byType(PinCodeUnlockInputScreen))
          .read<AppUnlockBloc>();
      await until(() => bloc.state.status == AppUnlockStatus.inProgress);
      for (final digit in digits.split('')) {
        bloc.add(AppUnlockPinCodeNumberAdded(int.parse(digit)));
      }
      await until(() => bloc.state.pinCode.length == digits.length);
      bloc.add(const AppUnlockSubmitted());
      await until(
        () =>
            bloc.state.status == AppUnlockStatus.success ||
            bloc.state.showError,
      );
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: localizations,
        home: BlocProvider<AppStartupBloc>.value(
          value: state,
          child: AppStartupWidget(
            app: const SizedBox.shrink(),
            onUnlocked: startup.start,
            splash: const SizedBox.shrink(),
            openOnboarding: () {},
            logs: () => throw StateError('Unexpected failure'),
          ),
        ),
      ),
    );
    await pin('9999');
    expect(initializations, 0);
    expect(requested, isEmpty);
    initializing.complete(const Ok(null));
    await pin('4315');
    expect(initializations, 1);
    expect(requested.map((value) => value.key), [btc, liquid]);

    await tester.runAsync(() async {
      expect(await inventory.lock(), isTrue);
    });
    final uri = Uri.parse('/settings?tab=network');
    final router = GoRouter(
      initialLocation: uri.toString(),
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('Settings detail')),
        ),
        ...feature.routes.root,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: theme,
        localizationsDelegates: localizations,
      ),
    );
    returnAfterWalletUnlock(router, uri, startup).go(router);
    await tester.pumpAndSettle();
    await pin('4315');
    expect(find.text('Settings detail'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri, uri);
    expect(initializations, 1);
    expect(requested.skip(2).map((value) => value.key), [btc, liquid]);
  });
}
