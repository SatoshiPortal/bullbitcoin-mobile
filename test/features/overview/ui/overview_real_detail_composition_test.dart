import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/overview_router.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:coins/coins.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/catalogue.dart';
import 'package:overview/overview.dart';
import 'package:overview/routes.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/storage.dart';
import 'package:send/send.dart';
import 'package:settings/settings.dart';
import 'package:settings/testing.dart';
import 'package:startup/startup.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';
import 'package:transactions/testing.dart';

import '../../../../packages/secrets/test/support/open_inventory.dart';
import '../../../../packages/sync/test/support/connections.dart';
import '../../../../packages/sync/test/support/regtest_wallet.dart'
    show regtestDescriptor;
import '../../../support/preferences_database.dart';
import '../support/overview_home_harness.dart';

class _History extends Mock implements TransactionsCubit {}

class _Settings extends Mock implements SettingsCubit {}

class _Consolidation extends Mock implements Consolidation {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await BullSdk.init();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  for (final scenario in [
    'bitcoin-watch',
    'bitcoin-remote',
    'bitcoin-local',
    'liquid-watch',
    'bitcoin-pending',
    'bitcoin-failed',
  ]) {
    testWidgets('real detail route resolves $scenario', (tester) async {
      tester.view.physicalSize = const Size(440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = await tester.runAsync(() async {
        final temp = await Directory.systemTemp.createTemp('overview-route-');
        final storage = await openFreshInventory(temp);
        final inventory = storage.inventory;
        final db = await createPreferencesDatabase();
        final preferences = PreferencesTesting.fromDao(PreferencesDao(db));
        valueOf(await preferences.setIsSuperuser(true));
        valueOf(await preferences.setIsDevMode(true));
        valueOf(await preferences.setEnvironment(Environment.regtest));
        final vector = regtestDescriptor();
        final liquid = scenario == 'liquid-watch';
        final key = WalletKey(
          id: liquid
              ? 'elwpkh([73c5da0a/84h/1h/0h]):regtest'
              : '${vector.origin}:regtest',
          network: liquid ? LiquidNetwork.regtest : BitcoinNetwork.regtest,
        );
        final liquidFixture = jsonDecode(
          await File('packages/sync/test/fixtures/retained_liquid_deposit.json')
              .readAsString(),
        ) as Map<String, dynamic>;
        valueOf(
          await inventory.registerWallet(
            scenario == 'bitcoin-local'
                ? RegisteredWallet(
                    id: key.id,
                    secretFingerprint: '73c5da0a',
                    masterFingerprint: '73c5da0a',
                    signer: 'local',
                    network: 'bitcoinRegtest',
                    xpub: 'fixture',
                    externalDescriptor: vector.externalDescriptor,
                    internalDescriptor: vector.internalDescriptor,
                    label: 'Savings',
                    birthday: null,
                    isDefault: false,
                  )
                : watchOnlyWallet(
                    key.id,
                    network: liquid ? 'liquidRegtest' : 'bitcoinRegtest',
                    signer: scenario == 'bitcoin-remote' ? 'remote' : 'none',
                    external: liquid
                        ? liquidFixture['descriptor'] as String
                        : vector.externalDescriptor,
                    internal: liquid ? '' : vector.internalDescriptor,
                    label: 'Savings',
                  ),
          ),
        );
        final connections = FixtureConnections([]);
        final hydration = Completer<void>();
        final hydrationAttempted = Completer<void>();
        final native = WalletNativeRuntime.open(
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
          beforeBalanceHydration: scenario == 'bitcoin-pending'
              ? () => hydration.future
              : scenario == 'bitcoin-failed'
              ? () async {
                  if (!hydrationAttempted.isCompleted) {
                    hydrationAttempted.complete();
                  }
                  throw Exception('private-read-detail');
                }
              : null,
        );
        final balances = ForegroundBalanceStartup.mount(
          runtime: () => native,
          inventory: inventory,
          preferences: preferences,
        );
        final startup = ForegroundWalletStartup(
          initialize: native.initialize,
          startWatchers: () {},
          balances: balances,
        );
        final catalogue = OverviewCatalogue.mount(
          balances: balances.observation,
          inventory: inventory,
        );
        final h = OverviewHomeHarness();
        await h.mount();
        locator.registerSingleton<OverviewCatalogue>(catalogue);
        locator.registerSingleton<OverviewHomeController>(h.controller);
        addTearDown(() async {
          if (!hydration.isCompleted) hydration.complete();
          await locator.unregister<OverviewHomeController>();
          await locator.unregister<OverviewCatalogue>();
          await h.close();
          await catalogue.close();
          await startup.dispose();
          valueOf(await native.close());
          await preferences.close();
          await db.close();
          await inventory.close();
          await storage.admission.close();
          await temp.delete(recursive: true);
        });
        await startup.start();
        for (var i = 0; i < 300; i++) {
          if (catalogue.snapshot.rows.any(
            (row) =>
                row.entry.key == key &&
                (scenario == 'bitcoin-pending' ||
                    (scenario == 'bitcoin-failed' &&
                        hydrationAttempted.isCompleted) ||
                    row.balanceSat != null),
          )) {
            return (key: key, inventory: inventory, home: h);
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('Bitcoin receipt did not become available');
      });
      if (fixture == null) fail('Fixture setup failed');
      final key = fixture.key;
      final history = _History();
      when(() => history.state)
          .thenReturn(const TransactionsState(transactions: []));
      when(() => history.stream).thenAnswer((_) => const Stream.empty());
      when(() => history.loadTxs()).thenAnswer((_) async {});
      when(() => history.resumeReloads()).thenAnswer((_) async {});
      final settings = _Settings();
      when(() => settings.state).thenReturn(
        const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.regtest,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
            hideAmounts: false,
          ),
        ),
      );
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());
      final consolidation = _Consolidation();
      when(() => consolidation.isRequired(key.id))
          .thenAnswer((_) async => const Ok(false));
      final historyIds = <String>[];
      final summaryIds = <String>[];
      final opened = <WalletKey>[];
      final route = OverviewRouter.walletDetailRoute(
        scopeWalletHistory: (id, child) {
          historyIds.add(id);
          return BlocProvider<TransactionsCubit>.value(
            value: history,
            child: child,
          );
        },
        loadCoinSummary: (id) async {
          summaryIds.add(id);
          return Ok((count: 3, frozenSat: BigInt.zero));
        },
        onOpenCoins: (_, wallet) async => opened.add(wallet),
      );
      final router = GoRouter(
        routes: [route],
        initialLocation: '/wallet/${Uri.encodeComponent(key.id)}',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsCubit>.value(value: settings),
            BitcoinPriceFixture.prices(),
          ],
          child: RepositoryProvider<Consolidation>.value(
            value: consolidation,
            child: MaterialApp.router(
              theme: AppTheme.themeData(AppThemeType.values.first),
              routerConfig: router,
              builder: (context, child) {
                Device.init(context);
                return Settings.amountScope(
                  navigatorKey: router.routerDelegate.navigatorKey,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              localizationsDelegates: const [
                ...bullUiLocalizationsDelegates,
                ...appLocalizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      if (scenario == 'bitcoin-pending' || scenario == 'bitcoin-failed') {
        final context = tester.element(find.byType(OverviewWalletButtons));
        expect(find.text(context.loc.walletLoadFailed), findsOneWidget);
        expect(find.textContaining('private-read-detail'), findsNothing);
        expect(find.byType(BullPullableBody), findsNothing);
        expect(historyIds, isEmpty);
        expect(summaryIds, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        return;
      }
      expect(route.name, WalletRoute.walletDetail.name);
      expect(find.text('Savings'), findsOneWidget);
      expect(historyIds.toSet(), {key.id});
      expect(find.byType(WalletDetailBalanceCard), findsOneWidget);
      expect(find.byType(EyeToggle), findsOneWidget);
      expect(find.byType(TxsSyncingIndicator), findsOneWidget);
      expect(find.byType(OverviewWalletButtons), findsOneWidget);
      final card = tester.widget<WalletDetailBalanceCard>(
        find.byType(WalletDetailBalanceCard),
      );
      expect(card.isLiquid, scenario == 'liquid-watch');
      expect(card.signer, switch (scenario) {
        'bitcoin-local' => SignerEntity.local,
        'bitcoin-remote' => SignerEntity.remote,
        _ => SignerEntity.none,
      });
      expect(
        tester
            .widget<WalletDetailBalanceAmount>(
              find.byType(WalletDetailBalanceAmount),
            )
            .balanceSat,
        0,
      );
      final buttons = tester.widget<BullReceiveSendButtons>(
        find.byType(BullReceiveSendButtons),
      );
      expect(buttons.onSend == null, scenario.endsWith('watch'));
      final body = tester.widget<BullPullableBody>(
        find.byType(BullPullableBody),
      );
      expect(body.slivers.last, isA<WalletDetailTxsList>());
      final context = tester.element(find.byType(OverviewWalletButtons));
      expect(find.text(context.loc.walletButtonReceive), findsOneWidget);
      expect(find.text(context.loc.walletButtonSend), findsOneWidget);
      if (scenario == 'liquid-watch') {
        expect(find.byType(BullDisclosureLink), findsOneWidget);
        expect(body.slivers, hasLength(7));
        expect(
          (body.slivers[1] as SliverToBoxAdapter).child,
          isA<ValueListenableBuilder<OverviewHomeState>>(),
        );
        expect(summaryIds, isEmpty);
        final disclosure = tester.widget<BullDisclosureLink>(
          find.byType(BullDisclosureLink),
        );
        await tester.ensureVisible(find.byType(BullDisclosureLink));
        await tester.tap(find.byType(BullDisclosureLink));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(disclosure.title), findsOneWidget);
        expect(
          tester
              .widget<BullDisclosureSheet>(find.byType(BullDisclosureSheet))
              .body,
          disclosure.body,
        );
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      } else {
        expect(body.slivers, hasLength(5));
        expect(summaryIds, [key.id]);
        final coins = find.text(context.loc.walletButtonCoins);
        await tester.ensureVisible(coins);
        await tester.tap(coins);
        await tester.pump();
        expect(opened, [key]);
        expect(summaryIds, [key.id, key.id]);
        expect(
          tester
              .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
              .utxoCount,
          3,
        );
      }
      fixture.home.sync.autoComplete = false;
      final refresh = body.onRefresh();
      await tester.pump();
      if (scenario != 'liquid-watch') {
        expect(summaryIds, [key.id, key.id]);
      }
      fixture.home.sync.completeNext(HomeSyncOutcome.completed);
      await refresh;
      await tester.pump();
      if (scenario != 'liquid-watch') {
        expect(summaryIds, [key.id, key.id, key.id]);
      }
      verifyInOrder([
        () => history.deferReloads(),
        () => history.resumeReloads(),
      ]);
      expect(fixture.home.sync.triggers.last, SyncTrigger.user);
      final scopedBeforeMissing = historyIds.length;
      router.go('/wallet/missing-wallet');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BullShimmerLine), findsOneWidget);
      expect(find.byType(BullShimmerBox), findsOneWidget);
      expect(find.byType(BullPullableBody), findsNothing);
      expect(find.byType(OverviewWalletButtons), findsNothing);
      expect(historyIds, hasLength(scopedBeforeMissing));
      router.go('/wallet/${Uri.encodeComponent(key.id)}');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final currentButtons = tester.widget<BullReceiveSendButtons>(
        find.byType(BullReceiveSendButtons),
      );
      await tester.runAsync(() async => fixture.inventory.lock());
      currentButtons.onReceive();
      currentButtons.onSend?.call();
      await tester.pump();
      expect(find.byType(OverviewWalletButtons), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
