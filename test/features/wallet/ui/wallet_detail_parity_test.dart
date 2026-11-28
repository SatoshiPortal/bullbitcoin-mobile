import 'dart:async';

import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_detail_screen.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/localizations.dart';
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
import 'package:overview/overview.dart';
import 'package:preferences/preferences.dart' show Environment, SettingsEntity;
import 'package:primitives/primitives.dart'
    show BitcoinUnit, Ok, Result, ScriptType, SignerEntity;
import 'package:send/send.dart';
import 'package:settings/settings.dart';
import 'package:settings/testing.dart';
import 'package:transactions/testing.dart';

class _WalletBloc extends Mock implements WalletBloc {}

class _TransactionsCubit extends Mock implements TransactionsCubit {}

class _SettingsCubit extends Mock implements SettingsCubit {}

class _Consolidation extends Mock implements Consolidation {}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });
  for (final scenario in ['bitcoin', 'liquid', 'missing', 'no balance']) {
    testWidgets('legacy wallet detail: $scenario', (tester) async {
      tester.view.physicalSize = const Size(440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final wallet = Wallet(
        origin: 'public-preview',
        label: 'Savings',
        network: scenario == 'liquid'
            ? Network.liquidMainnet
            : Network.bitcoinMainnet,
        isDefault: false,
        xpubFingerprint: '00000000',
        scriptType: ScriptType.bip84,
        xpub: '',
        externalPublicDescriptor: '',
        internalPublicDescriptor: '',
        signer: SignerEntity.local,
        signerDevice: null,
        balanceSat: scenario == 'no balance' ? null : BigInt.from(1000000),
      );
      final walletId = scenario == 'missing' ? 'missing-wallet' : wallet.id;
      const amountDisplay = (
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
        hideAmounts: false,
      );
      final bloc = _WalletBloc();
      final changes = StreamController<WalletState>.broadcast();
      addTearDown(changes.close);
      var state = WalletState(
        amountDisplay: amountDisplay,
        status: WalletStatus.success,
        wallets: [wallet],
        backupNeeded: false,
      );
      when(() => bloc.state).thenAnswer((_) => state);
      when(() => bloc.stream).thenAnswer((_) => changes.stream);
      final admission = StreamController<void>.broadcast();
      addTearDown(admission.close);
      int? generation = 1;
      when(() => bloc.walletActionsGeneration).thenAnswer((_) => generation);
      when(() => bloc.walletActionChanges).thenAnswer((_) => admission.stream);
      when(() => bloc.refresh()).thenAnswer((_) async {});

      final settings = _SettingsCubit();
      when(() => settings.state).thenReturn(
        const SettingsState(
          storedSettings: SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
            hideAmounts: false,
          ),
        ),
      );
      when(() => settings.stream).thenAnswer((_) => const Stream.empty());

      final history = _TransactionsCubit();
      when(() => history.state)
          .thenReturn(const TransactionsState(transactions: []));
      when(() => history.stream).thenAnswer((_) => const Stream.empty());
      when(() => history.loadTxs()).thenAnswer((_) async {});
      when(() => history.resumeReloads()).thenAnswer((_) async {});
      final consolidation = _Consolidation();
      when(() => consolidation.isRequired(wallet.id))
          .thenAnswer((_) async => const Ok(false));
      final historyIds = <String>[];
      final summaryIds = <String>[];
      final opened = <Wallet>[];
      final coinReturn = Completer<void>();
      final reload = Completer<Result<CoinSummary, CoinsFailure>>();
      final route = WalletRouter.walletDetailRoute(
        scopeWalletHistory: (id, child) {
          historyIds.add(id);
          return BlocProvider<TransactionsCubit>.value(
            value: history,
            child: child,
          );
        },
        loadCoinSummary: (id) async {
          summaryIds.add(id);
          return summaryIds.length == 1
              ? Ok((count: 3, frozenSat: BigInt.zero))
              : reload.future;
        },
        onOpenCoins: (_, wallet) {
          opened.add(wallet);
          return coinReturn.future;
        },
      );
      expect(route.name, 'walletDetail');
      expect(route.path, '/wallet/:walletId');
      expect(WalletRoute.walletHome.name, 'walletHome');
      expect(WalletRoute.walletHome.path, '/wallet');
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/wallet',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pushNamed(
                  'walletDetail',
                  pathParameters: {'walletId': walletId},
                ),
                child: const Text('Open wallet'),
              ),
            ),
          ),
          route,
        ],
        initialLocation: scenario == 'bitcoin'
            ? '/wallet'
            : '/wallet/$walletId',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<WalletBloc>.value(value: bloc),
            BlocProvider<SettingsCubit>.value(value: settings),
            BitcoinPriceFixture.prices(
              amountDisplay: amountDisplay,
              currency: 'CAD',
              bitcoinPrice: 125000,
            ),
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
      if (scenario == 'bitcoin') {
        await tester.tap(find.text('Open wallet'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      final screen = find.byType(WalletDetailScreen);
      expect(tester.widget<WalletDetailScreen>(screen).walletId, walletId);
      final loc = tester.element(screen).loc;
      final body = find.byType(BullPullableBody);
      if (scenario == 'missing') {
        expect(find.byType(BullShimmerLine), findsOneWidget);
        expect(find.byType(BullShimmerBox), findsOneWidget);
        expect(find.text(loc.walletLoadFailed), findsNothing);
        expect(find.byType(OverviewWalletButtons), findsNothing);
        expect(body, findsNothing);
        expect(historyIds, isEmpty);
      } else if (scenario == 'no balance') {
        expect(find.text(loc.walletLoadFailed), findsOneWidget);
        expect(find.byType(OverviewWalletButtons), findsOneWidget);
        expect(body, findsNothing);
        expect(historyIds, isEmpty);
      } else {
        expect(find.text('Savings'), findsOneWidget);
        expect(historyIds.toSet(), {wallet.id});
        expect(find.byType(WalletDetailBalanceCard), findsOneWidget);
        expect(find.byType(EyeToggle), findsOneWidget);
        expect(find.byType(TxsSyncingIndicator), findsOneWidget);
        expect(find.byType(OverviewWalletButtons), findsOneWidget);
        expect(find.text(loc.walletButtonSend), findsOneWidget);
        expect(find.text(loc.walletButtonReceive), findsOneWidget);
        final pull = tester.widget<BullPullableBody>(body);
        final slivers = pull.slivers;
        expect(
          (slivers.first as SliverToBoxAdapter).child,
          isA<WalletDetailBalanceCard>(),
        );
        expect(slivers.last, isA<WalletDetailTxsList>());
        final liquid = scenario == 'liquid';
        expect(slivers, hasLength(liquid ? 7 : 5));
        if (liquid) {
          expect(
            (slivers[1] as SliverToBoxAdapter).child,
            isA<ConsolidationBanner>(),
          );
          final disclosure =
              (slivers[4] as SliverToBoxAdapter).child as Padding;
          expect(disclosure.child, isA<BullDisclosureLink>());
          expect(summaryIds, [wallet.id]);
          expect(find.text(loc.walletButtonCoins), findsOneWidget);
        } else {
          expect(summaryIds, [wallet.id]);
          final coins = find.text(loc.walletButtonCoins);
          await tester.ensureVisible(coins);
          await tester.tap(coins);
          await tester.pump();
          expect(opened, [wallet]);
          expect(summaryIds, [wallet.id]);
          coinReturn.complete();
          await tester.pump();
          expect(summaryIds, [wallet.id, wallet.id]);
          expect(
            tester
                .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
                .utxoCount,
            3,
          );
          state = state.copyWith(isRefreshing: true);
          changes.add(state);
          await tester.pump();
          expect(summaryIds, hasLength(2));
          state = state.copyWith(isRefreshing: false);
          changes.add(state);
          await tester.pump();
          expect(summaryIds, [wallet.id, wallet.id, wallet.id]);
          reload.complete(Ok((count: 5, frozenSat: BigInt.zero)));
          await tester.pump();
          expect(
            tester
                .widget<CoinsEntrySubtitle>(find.byType(CoinsEntrySubtitle))
                .utxoCount,
            5,
          );
        }
        await pull.onRefresh();
        verifyInOrder([
          () => history.deferReloads(),
          () => bloc.refresh(),
          () => history.resumeReloads(),
        ]);
        generation = null;
        admission.add(null);
        await tester.pumpAndSettle();
        expect(find.byType(OverviewWalletButtons), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
