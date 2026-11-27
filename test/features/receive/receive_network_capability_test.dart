import 'package:bb_mobile/features/wallet/domain/wallet.dart' as legacy;
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:primitives/primitives.dart' show ScriptType;
import 'package:primitives/primitives.dart' as primitives;
import 'package:receive/receive.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
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

class _WalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

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

  testWidgets(
    'Liquid regtest Receive button opens the Boltz Lightning route with its wallet',
    (tester) async {
      final selected = wallet(LiquidNetwork.regtest);
      final legacyWallet = legacy.Wallet(
        origin: selected.id,
        network: legacy.Network.liquidRegtest,
        signer: SignerEntity.local,
        scriptType: ScriptType.bip84,
        xpubFingerprint: '',
        xpub: '',
        externalPublicDescriptor: '',
        internalPublicDescriptor: '',
        signerDevice: null,
        balanceSat: BigInt.zero,
      );
      final catalogue = _WalletBloc();
      var generation = 1;
      final actionChanges = StreamController<void>.broadcast();
      addTearDown(actionChanges.close);
      when(() => catalogue.walletActionChanges)
          .thenAnswer((_) => actionChanges.stream);
      when(() => catalogue.walletActionsGeneration)
          .thenAnswer((_) => generation);
      whenListen(
        catalogue,
        const Stream<WalletState>.empty(),
        initialState: WalletState(wallets: [legacyWallet]),
      );
      Object? received;
      Object? sent;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<WalletBloc>.value(
              value: catalogue,
              child: Scaffold(
                body: WalletBottomButtons.detail(wallet: legacyWallet),
              ),
            ),
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
        tester.element(find.byType(WalletBottomButtons)),
      );
      await tester.tap(find.text(loc.walletButtonReceive));
      await tester.pumpAndSettle();
      expect(find.text('Lightning route'), findsOneWidget);
      expect(find.text('Liquid route'), findsNothing);
      expect(received, isA<ReceiveWallet>());
      expect((received as ReceiveWallet).network, LiquidNetwork.regtest);
      expect((received as ReceiveWallet).id, '${selected.id}:regtest');
      expect((received as ReceiveWallet).scriptType, ScriptType.bip84);
      expect((received as ReceiveWallet).signsLocally, isTrue);
      expect(tester.takeException(), isNull);

      router.pop();
      await tester.pumpAndSettle();
      final buttons = tester.widget<BullReceiveSendButtons>(
        find.byType(BullReceiveSendButtons),
      );
      await tester.tap(find.text(loc.walletButtonSend));
      await tester.pumpAndSettle();
      expect(find.text('Send route'), findsOneWidget);
      expect(sent, isNotNull);
      router.pop();
      await tester.pumpAndSettle();
      generation++;
      received = null;
      sent = null;
      buttons.onReceive();
      buttons.onSend?.call();
      await tester.pumpAndSettle();
      expect(received, isNull);
      expect(sent, isNull);
      expect(find.byType(WalletBottomButtons), findsOneWidget);

      // A new admission need not change WalletState (the same catalogue can
      // be published after re-authentication).
      actionChanges.add(null);
      await tester.pumpAndSettle();
      await tester.tap(find.text(loc.walletButtonReceive));
      await tester.pumpAndSettle();
      expect(find.text('Lightning route'), findsOneWidget);
    },
  );

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
