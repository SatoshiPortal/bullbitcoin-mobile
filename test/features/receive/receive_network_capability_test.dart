import 'dart:io';

import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/overview_router.dart';
import 'package:overview/catalogue.dart';
import 'package:overview/overview.dart';
import 'package:secrets/storage.dart';
import 'package:startup/startup.dart';
import 'package:sync/sync.dart';

import '../../../packages/secrets/test/support/open_inventory.dart';
import '../overview/support/overview_home_harness.dart';

import 'package:primitives/primitives.dart' show ScriptType;
import 'package:primitives/primitives.dart' as primitives;
import 'package:receive/receive.dart';

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:send/send.dart' show SendRoute;
import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bull_ui/app_theme.dart';
import 'package:receive/testing.dart';
import 'package:primitives/primitives.dart'
    show Network, BitcoinNetwork, LiquidNetwork;
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSegmented, BullReceiveSendButtons;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiveWallet wallet(
  Network network, {
  SignerEntity signer = SignerEntity.local,
}) => ReceiveWallet(
  id: "review/84'/1'/0'",
  network: network,
  scriptType: ScriptType.bip84,
  signsLocally: signer == SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

class _ReceiveBloc extends MockBloc<ReceiveEvent, ReceiveState>
    implements ReceiveBloc {}

void main() {
  for (final network in <Network>[
    ...BitcoinNetwork.values.where((n) => n != BitcoinNetwork.signet),
    ...LiquidNetwork.values,
  ]) {
    for (final signer in [SignerEntity.local, SignerEntity.none]) {
      test('default Receive mode is available for $network / $signer', () {
        final selected = wallet(network, signer: signer);
        final expected = switch ((network, signer)) {
          (
            LiquidNetwork.mainnet ||
                LiquidNetwork.testnet ||
                LiquidNetwork.regtest,
            SignerEntity.local,
          ) =>
            ReceiveNetworkType.lightning,
          (
            LiquidNetwork.mainnet ||
                LiquidNetwork.testnet ||
                LiquidNetwork.regtest,
            _,
          ) =>
            ReceiveNetworkType.liquid,
          _ => ReceiveNetworkType.bitcoin,
        };
        expect(selected.defaultReceiveNetwork, expected);
        expect(
          selected.availableReceiveNetworks,
          contains(selected.defaultReceiveNetwork),
        );
      });
    }
  }

  testWidgets('Liquid regtest selector has a supported initial selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReceiveNetworkSelection(wallet: wallet(LiquidNetwork.regtest)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final loc = AppLocalizations.of(
      tester.element(find.byType(ReceiveNetworkSelection)),
    );
    final selector = tester.widget<BullSegmented>(find.byType(BullSegmented));
    expect(selector.items, {loc.receiveLightning, loc.receiveLiquid});
    expect(selector.initialValue, loc.receiveLightning);
    expect(find.text(loc.receiveLightning), findsOneWidget);
    expect(
      primitives.NetworkCapabilities.supports(
        primitives.LiquidNetwork.regtest,
        primitives.NetworkCapability.exchange,
      ),
      isFalse,
    );
  });

  for (final signer in ['local', 'none']) {
    testWidgets('Liquid regtest detail Receive and Send for $signer', (
      tester,
    ) async {
      const id = 'elwpkh([01234567/84h/1h/0h]):regtest';
      late Directory directory;
      late SecretsInventory inventory;
      late ForegroundBalanceStartup balances;
      late OverviewCatalogue catalogue;
      late Future<void> Function() closeInventory;
      var syncRequests = 0;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'receive-navigation-',
        );
        final fixture = await openFreshInventory(directory);
        inventory = fixture.inventory;
        closeInventory = () async {
          await inventory.close();
          await fixture.admission.close();
          await directory.delete(recursive: true);
        };
        valueOf(
          await inventory.registerWallet(
            RegisteredWallet(
              id: id,
              secretFingerprint: signer == 'local' ? '01234567' : null,
              masterFingerprint: '01234567',
              signer: signer,
              network: 'liquidRegtest',
              xpub: 'tpubMarker',
              externalDescriptor:
                  "ct(blinded,elwpkh([01234567/84'/1'/0']tpubMarker/0/*))",
              internalDescriptor:
                  "ct(blinded,elwpkh([01234567/84'/1'/0']tpubMarker/1/*))",
              label: null,
              birthday: null,
              isDefault: false,
            ),
          ),
        );
        balances = ForegroundBalanceStartup.testing(
          catalogue: inventory.walletCatalogue,
          session: inventory.foregroundSession,
          transitions: const Stream.empty(),
          environmentChanging: () => false,
          readEnvironment: () async => primitives.NetworkEnv.regtest,
          select: (_) async => const primitives.Ok([]),
          revisions: () => const Stream.empty(),
          capture: (_, _, {catalogue}) {
            syncRequests++;
            return null;
          },
          demand: (_) => throw StateError('Unexpected sync demand'),
        );
        catalogue = OverviewCatalogue.mount(
          balances: balances.observation,
          inventory: inventory,
        );
        balances.admitUnlock();
        balances.initialized(const primitives.Ok(null));
        for (var i = 0; i < 100 && catalogue.snapshot.rows.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(catalogue.snapshot.rows, hasLength(1));
      });
      final home = OverviewHomeHarness();
      locator.pushNewScope();
      locator.registerSingleton<OverviewCatalogue>(catalogue);
      locator.registerSingleton<OverviewHomeController>(home.controller);
      addTearDown(() async {
        await locator.popScope();
        await home.close();
        await catalogue.close();
        await balances.dispose();
        await closeInventory();
      });
      Object? received;
      Object? sent;
      final router = GoRouter(
        initialLocation: '/wallet/${Uri.encodeComponent(id)}',
        routes: [
          OverviewRouter.walletDetailRoute(
            scopeWalletHistory: (_, child) => child,
            onOpenCoins: (_, _) async {},
            loadCoinSummary: (_) => throw StateError('Unexpected coins'),
          ),
          GoRoute(
            path: '/send',
            name: SendRoute.send.name,
            builder: (_, state) {
              sent = state.extra;
              return const Scaffold(body: Text('Send route'));
            },
          ),
          GoRoute(
            path: '/liquid',
            name: ReceiveRoute.receiveLiquid.name,
            builder: (_, state) {
              received = state.extra;
              return const Scaffold(body: Text('Liquid route'));
            },
          ),
          GoRoute(
            path: '/lightning',
            name: ReceiveRoute.receiveLightning.name,
            builder: (_, state) {
              received = state.extra;
              return const Scaffold(body: Text('Lightning route'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      final loc = AppLocalizations.of(
        tester.element(find.byType(OverviewWalletButtons)),
      );
      final buttons = tester.widget<BullReceiveSendButtons>(
        find.byType(BullReceiveSendButtons),
      );
      expect(buttons.onSend == null, signer == 'none');
      await tester.tap(find.text(loc.walletButtonReceive));
      await tester.pumpAndSettle();
      expect(
        find.text(signer == 'local' ? 'Lightning route' : 'Liquid route'),
        findsOneWidget,
      );
      expect(received, isA<ReceiveWallet>());
      final target = received as ReceiveWallet;
      expect(target.network, LiquidNetwork.regtest);
      expect(target.id, id);
      expect(target.scriptType, ScriptType.bip84);
      expect(target.signsLocally, signer == 'local');
      expect(syncRequests, 0);
      expect(home.sync.triggers, isEmpty);
      router.pop();
      await tester.pumpAndSettle();
      if (signer == 'local') {
        await tester.tap(find.text(loc.walletButtonSend));
        await tester.pumpAndSettle();
        expect(find.text('Send route'), findsOneWidget);
        // The route argument type is intentionally private to Send, but its
        // wallet must carry the exact admitted identity across the boundary.
        expect(
          (sent as dynamic).wallet,
          WalletKey(id: id, network: LiquidNetwork.regtest),
        );
        router.pop();
        await tester.pumpAndSettle();
      }
      balances.revokeUnlock();
      received = null;
      sent = null;
      buttons.onReceive();
      buttons.onSend?.call();
      await tester.pumpAndSettle();
      expect(received, isNull);
      expect(sent, isNull);
      balances.admitUnlock();
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && catalogue.snapshot.rows.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(catalogue.snapshot.rows, hasLength(1));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.walletButtonReceive));
      await tester.pumpAndSettle();
      expect(received, isA<ReceiveWallet>());
      expect(
        find.text(signer == 'local' ? 'Lightning route' : 'Liquid route'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final network in [
    BitcoinNetwork.mainnet,
    BitcoinNetwork.testnet,
    BitcoinNetwork.regtest,
  ]) {
    testWidgets('Receive selector respects capabilities for ${network.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReceiveNetworkSelection(wallet: wallet(network)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(ReceiveNetworkSelection));
      final loc = AppLocalizations.of(element);
      final selection = tester.widget<BullSegmented>(
        find.byType(BullSegmented),
      );
      expect(selection.items, {loc.receiveBitcoin, loc.receiveLightning});
    });
  }
  for (final network in [
    BitcoinNetwork.mainnet,
    BitcoinNetwork.testnet,
    BitcoinNetwork.regtest,
  ]) {
    for (final fromHome in [true, false]) {
      testWidgets('Receive scaffold ${network.name} fromHome=$fromHome', (
        tester,
      ) async {
        final bloc = _ReceiveBloc();
        final states = StreamController<ReceiveState>();
        whenListen(bloc, states.stream, initialState: const ReceiveState());
        final router = GoRouter(
          initialLocation: '/receive/bitcoin',
          routes: [
            GoRoute(
              path: '/receive/bitcoin',
              builder: (_, _) => BlocProvider<ReceiveBloc>.value(
                value: bloc,
                child: ReceiveScaffold(
                  wallet: fromHome ? null : wallet(network),
                  poll: PollReceiveWalletUsecase(
                    (_, {required isActive}) async {},
                  ),
                  openHome: (_) {},
                  child: const SizedBox(),
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        // Inspect both the loading state and the prepared Home entry.
        final loadingModes = tester
            .widgetList<BullSegmented>(find.byType(BullSegmented))
            .map((w) => w.items)
            .toList();
        states.add(
          ReceiveState(type: ReceiveType.bitcoin, wallet: wallet(network)),
        );
        await tester.pumpAndSettle();
        final selection = tester.widget<BullSegmented>(
          find.byType(BullSegmented),
        );
        final loc = AppLocalizations.of(
          tester.element(find.byType(ReceiveScaffold)),
        );
        expect(selection.items, {
          loc.receiveBitcoin,
          loc.receiveLightning,
          if (fromHome) loc.receiveLiquid,
        });
        if (fromHome) expect(loadingModes, isEmpty);
        {
          // Lightning's settlement wallet must not change the entry's modes.
          final liquid = LiquidNetwork.values.firstWhere(
            (n) => n.env == network.env,
          );
          states.add(
            ReceiveState(type: ReceiveType.lightning, wallet: wallet(liquid)),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<BullSegmented>(find.byType(BullSegmented)).items,
            selection.items,
          );
          states.add(
            ReceiveState(
              type: ReceiveType.bitcoin,
              wallet: wallet(network, signer: SignerEntity.none),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<BullSegmented>(find.byType(BullSegmented)).items,
            fromHome ? selection.items : {loc.receiveBitcoin},
          );
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        await states.close();
        await bloc.close();
      });
    }
  }
}
