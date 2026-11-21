import 'package:primitives/primitives.dart' show ScriptType;
import 'package:primitives/primitives.dart' as primitives;
import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';
import 'package:bb_mobile/features/receive/domain/extensions/wallet_receive_extensions.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';

import 'dart:async';

import 'package:bb_mobile/features/receive/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_scaffold.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_network_selection.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart' show BullSegmented;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Wallet wallet(Network network, {SignerEntity signer = SignerEntity.local}) =>
    Wallet(
      origin: "review/84'/1'/0'",
      network: network,
      xpubFingerprint: 'review-public-fixture',
      scriptType: ScriptType.bip84,
      xpub: 'unused-public-fixture',
      externalPublicDescriptor: 'unused-public-fixture',
      internalPublicDescriptor: 'unused-public-fixture',
      signer: signer,
      signerDevice: null,
      balanceSat: BigInt.zero,
    );

class _ReceiveBloc extends MockBloc<ReceiveEvent, ReceiveState>
    implements ReceiveBloc {}

void main() {
  for (final network in Network.values) {
    for (final signer in [SignerEntity.local, SignerEntity.none]) {
      test('default Receive mode is available for $network / $signer', () {
        final selected = wallet(network, signer: signer);
        final expected = switch ((network, signer)) {
          (
            Network.liquidMainnet ||
                Network.liquidTestnet ||
                Network.liquidRegtest,
            SignerEntity.local,
          ) =>
            ReceiveNetworkType.lightning,
          (
            Network.liquidMainnet ||
                Network.liquidTestnet ||
                Network.liquidRegtest,
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
          body: ReceiveNetworkSelection(wallet: wallet(Network.liquidRegtest)),
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
      final selected = wallet(Network.liquidRegtest);
      Object? received;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(body: WalletBottomButtons(wallet: selected)),
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
      expect(received, same(selected));
      expect(tester.takeException(), isNull);
    },
  );

  for (final network in [
    Network.bitcoinMainnet,
    Network.bitcoinTestnet,
    Network.bitcoinRegtest,
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
    Network.bitcoinMainnet,
    Network.bitcoinTestnet,
    Network.bitcoinRegtest,
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
                    WalletFacade(const Stream.empty()),
                  ),
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
          final liquid = Network.fromEnvironment(
            environment: network.environment,
            isLiquid: true,
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
