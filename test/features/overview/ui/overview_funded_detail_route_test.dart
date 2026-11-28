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
import 'package:electrum/electrum.dart';
import 'package:fees/fees.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/catalogue.dart';
import 'package:overview/overview.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:receive/receive.dart' show ReceiveWallet;
import 'package:receive/testing.dart'
    show ReceiveRouter, PollReceiveWalletUsecase;
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/storage.dart';
import 'package:send/send.dart';
import 'package:send/setup.dart';
import 'package:settings/settings.dart';
import 'package:settings/testing.dart';
import 'package:startup/startup.dart';
import 'package:spend/spend.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';
import 'package:transactions/testing.dart';

import '../../../../packages/secrets/test/support/open_inventory.dart';
import '../../../../packages/sync/test/support/connections.dart';
import '../../../../packages/sync/test/support/native_funding.dart';
import '../../../../packages/sync/test/support/regtest_wallet.dart'
    show regtestDescriptor;
import '../../../../packages/sync/test/support/second_revision_connection.dart';
import '../../../support/preferences_database.dart';
import '../support/overview_home_harness.dart';

class _History extends Mock implements TransactionsCubit {}

class _Settings extends Mock implements SettingsCubit {}

class _Consolidation extends Mock implements Consolidation {}

class _Spend extends Mock implements Spend {}

class _Fees extends Mock implements Fees {}

class _Electrum extends Mock implements Electrum {}

class _ElectrumTransactions extends Mock implements ElectrumTransactions {}

class _Environment extends Mock implements ActiveEnvironmentReader {}

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

  for (final variant in ['bitcoin-local', 'liquid-local', 'liquid-remote']) {
    testWidgets('real detail route displays funded native $variant', (
      tester,
    ) async {
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
        final liquid = variant.startsWith('liquid');
        final liquidFixture = jsonDecode(
          await File('packages/sync/test/fixtures/retained_liquid_deposit.json')
              .readAsString(),
        ) as Map<String, dynamic>;
        final key = WalletKey(
          id: liquid
              ? 'elwpkh([73c5da0a/84h/1h/0h]):regtest'
              : '${vector.origin}:regtest',
          network: liquid ? LiquidNetwork.regtest : BitcoinNetwork.regtest,
        );
        valueOf(
          await inventory.registerWallet(
            variant == 'liquid-remote'
                ? watchOnlyWallet(
                    key.id,
                    network: 'liquidRegtest',
                    signer: 'remote',
                    external: liquidFixture['descriptor'] as String,
                    label: 'Savings',
                  )
                : RegisteredWallet(
                    id: key.id,
                    secretFingerprint: '73c5da0a',
                    masterFingerprint: '73c5da0a',
                    signer: 'local',
                    network: liquid ? 'liquidRegtest' : 'bitcoinRegtest',
                    xpub: 'fixture',
                    externalDescriptor: liquid
                        ? liquidFixture['descriptor'] as String
                        : vector.externalDescriptor,
                    // This native LWK fixture has no change chain; this case
                    // verifies signer projection, not internal derivation.
                    internalDescriptor: liquid ? '' : vector.internalDescriptor,
                    label: 'Savings',
                    birthday: null,
                    isDefault: false,
                  ),
          ),
        );
        final connections = FixtureConnections([]);
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
        valueOf(await native.initialize());
        final store = SecondRevisionConnection(
          revisionStorePath('${temp.path}/native'),
        );
        try {
          store.begin(key, WriteIntent.sync);
          if (liquid) {
            final update = File(
              '${nativeWalletStoragePath('${temp.path}/native', key)}/${liquidFixture['path']}',
            );
            await update.parent.create(recursive: true);
            await update.writeAsBytes(
              base64Decode(liquidFixture['update'] as String),
            );
          } else {
            fundBitcoinNativeStore(
              '${temp.path}/native',
              BitcoinWalletDescriptor(
                key: key,
                scriptType: vector.scriptType,
                origin: vector.origin,
                externalDescriptor: vector.externalDescriptor,
                internalDescriptor: vector.internalDescriptor,
              ),
            );
          }
          store.finish(key);
        } finally {
          store.close();
        }
        locator.registerSingleton<OverviewCatalogue>(catalogue);
        locator.registerSingleton<OverviewHomeController>(h.controller);
        addTearDown(() async {
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
            (row) => row.entry.key == key && row.balanceSat != null,
          )) {
            return (key: key, inventory: inventory, home: h);
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('$variant receipt did not become available');
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
      final coinReturn = Completer<void>();
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
        onOpenCoins: (_, wallet) async {
          opened.add(wallet);
          await coinReturn.future;
        },
      );
      final root = GlobalKey<NavigatorState>();
      final detailPath = '/wallet/${Uri.encodeComponent(key.id)}';
      ReceiveWallet? received;
      Object? sent;
      String? receiveDestination;
      final receiveRoute = ReceiveRouter.mount(
        rootNavigatorKey: root,
        createBloc: (_) => throw StateError('Receive flow must not start'),
        poll: PollReceiveWalletUsecase((_, {required isActive}) async {}),
        openHome: (_) {},
        openPayjoinSettings: (_) {},
        successAnimation: const AssetImage('unused'),
      );
      final electrum = _Electrum();
      when(() => electrum.transactions).thenReturn(_ElectrumTransactions());
      final sendRoute = SendFeature.mount(
        spend: _Spend(),
        fees: _Fees(),
        electrum: electrum,
        environment: _Environment(),
        goToWalletHome: (_) {},
        broadcastSuccessImage: const AssetImage('unused'),
        missingWalletRedirect: detailPath,
        selectBalanceSat: (_, _) => null,
        payment: () => throw StateError('Send flow must not start'),
        openCoins: (_, _) {},
        orderUnderReview: (_) => const SizedBox.shrink(),
        pollSettlement: (_, {required isActive}) async {},
      ).payment;
      final router = GoRouter(
        navigatorKey: root,
        routes: [route, receiveRoute, sendRoute],
        initialLocation: detailPath,
        redirect: (_, state) {
          if (state.matchedLocation.startsWith('/receive/')) {
            receiveDestination = state.matchedLocation;
            received = state.extra as ReceiveWallet?;
            return detailPath;
          }
          if (state.matchedLocation == '/send') {
            sent = state.extra;
            return detailPath;
          }
          return null;
        },
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
      expect(historyIds.toSet(), {key.id});
      expect(
        tester
            .widget<WalletDetailBalanceAmount>(
              find.byType(WalletDetailBalanceAmount),
            )
            .balanceSat,
        variant.startsWith('liquid') ? 12345 : 54321,
      );
      final body = tester.widget<BullPullableBody>(
        find.byType(BullPullableBody),
      );
      final context = tester.element(find.byType(OverviewWalletButtons));
      if (variant == 'bitcoin-local') {
        expect(summaryIds, [key.id]);
        final coins = find.text(context.loc.walletButtonCoins);
        await tester.ensureVisible(coins);
        await tester.tap(coins);
        await tester.pump();
        expect(opened, [key]);
        expect(summaryIds, [key.id]);
        coinReturn.complete();
        await tester.pump();
        expect(summaryIds, [key.id, key.id]);
        expect(
          tester
              .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
              .utxoCount,
          3,
        );
      } else {
        expect(summaryIds, isEmpty);
        expect(find.byType(BullDisclosureLink), findsOneWidget);
      }
      fixture.home.sync.autoComplete = false;
      final refresh = body.onRefresh();
      await tester.pump();
      verify(() => history.deferReloads()).called(1);
      expect(fixture.home.sync.triggers.last, SyncTrigger.user);
      verifyNever(() => history.resumeReloads());
      expect(
        summaryIds,
        variant == 'bitcoin-local' ? [key.id, key.id] : isEmpty,
      );
      fixture.home.sync.completeNext(HomeSyncOutcome.completed);
      await refresh;
      await tester.pump();
      expect(
        summaryIds,
        variant == 'bitcoin-local' ? [key.id, key.id, key.id] : isEmpty,
      );
      verify(() => history.resumeReloads()).called(1);
      final buttons = tester.widget<BullReceiveSendButtons>(
        find.byType(BullReceiveSendButtons),
      );
      buttons.onReceive();
      await tester.pump();
      expect(receiveDestination, switch (variant) {
        'liquid-local' => '/receive/lightning',
        'liquid-remote' => '/receive/liquid',
        _ => '/receive/bitcoin',
      });
      expect(received?.id, key.id);
      expect(received?.network, key.network);
      expect(received?.scriptType, ScriptType.bip84);
      expect(received?.signsLocally, variant != 'liquid-remote');
      buttons.onSend?.call();
      await tester.pump();
      expect(sent, isNotNull);
      // SendRouteArgs is not exported by the public barrel; verify the real
      // router payload without importing the feature's private implementation.
      final dynamic sendArguments = sent;
      expect(sendArguments.wallet, key);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
