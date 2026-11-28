import 'dart:async';

import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_quick_actions/setup.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullCarousel, bullUiLocalizationsDelegate;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:swap_feature/swap_feature.dart' show HomeOngoingSwaps;
import 'package:swaps/swaps.dart';
import 'package:transactions/routes.dart';

class _WalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _Storage implements QuickActionsStorage {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}
}

Swap _swap(String id, int day, SwapType type) => Swap.chain(
  id: id,
  keyIndex: 0,
  type: type,
  status: SwapStatus.paid,
  environment: SwapEnvironment.regtest,
  creationTime: DateTime.utc(2026, 1, day),
  sendWalletId: 'wallet-$id',
  receiveWalletId: 'other-$id',
  paymentAddress: 'lockup',
  paymentAmount: 1000,
);

void main() {
  testWidgets('Wallet updates the notices and pushes the swiped swap details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final changes = StreamController<WalletState>();
    final wallets = _WalletBloc();
    addTearDown(changes.close);
    addTearDown(wallets.close);
    const display = (
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      hideAmounts: false,
    );
    const initial = WalletState(
      status: WalletStatus.success,
      amountDisplay: display,
    );
    whenListen(wallets, changes.stream, initialState: initial);
    final actions = QuickActionsFeature.mount(
      storage: _Storage(),
      isIOS: false,
      warning: (_) {},
      exchangeVisible: () => const Stream.empty(),
      exchangeEntry: () => const Stream.empty(),
      exchangeOffered: () => const Stream.empty(),
    );
    addTearDown(actions.close);
    GoRouterState? details;
    final router = GoRouter(
      initialLocation: WalletRoute.walletHome.path,
      routes: [
        WalletRouter.walletHomeRoute(
          arkHost: null,
          quickActions: () => actions.quickActions,
          exchangePrompt: () => actions.exchangePrompt,
          onQuickAction: (_, _) {},
          onCustomizeQuickActions: (_) {},
          onActivateExchange: (_) {},
          watchUnreadSupportMessages: (_) => 0,
          announcements: () => const SizedBox.shrink(),
          createSetupCubit: () => throw StateError('Unexpected Wallet setup'),
        ),
        GoRoute(
          name: TransactionsRoute.swapTransactionDetails.name,
          path: TransactionsRoute.swapTransactionDetails.path,
          builder: (_, state) {
            details = state;
            return const Scaffold(body: BackButton());
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<WalletBloc>.value(value: wallets),
          BitcoinPriceFixture.prices(
            amountDisplay: display,
            currency: 'CAD',
            bitcoinPrice: 100000,
          ),
          BitcoinPriceFixture.chart(),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: const [
            QuickActionsLocalizations.delegate,
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final notices = find.byType(HomeOngoingSwaps);
    final carousel = find.descendant(
      of: notices,
      matching: find.byType(BullCarousel),
    );
    expect(carousel, findsNothing);

    final first = _swap('first', 1, SwapType.bitcoinToLiquid);
    final second = _swap('second', 2, SwapType.liquidToBitcoin);
    changes.add(initial.copyWith(ongoingSwaps: [first, second]));
    await tester.pumpAndSettle();
    await tester.ensureVisible(carousel);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('second')).hitTestable(), findsNothing);
    await tester.fling(carousel, const Offset(-600, 0), 1200);
    await tester.pumpAndSettle();
    final secondCard = find.text('L-BTC → BTC').hitTestable();
    expect(secondCard, findsOneWidget);
    await tester.tap(secondCard);
    await tester.pumpAndSettle();

    expect(details?.pathParameters, {'swapId': 'second'});
    expect(details?.uri.queryParameters, {
      'walletId': 'wallet-second',
      'view': 'details',
    });
    expect(router.canPop(), isTrue);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(notices, findsOneWidget);
    expect(find.byKey(const ValueKey('second')).hitTestable(), findsOneWidget);
    changes.add(initial);
    await tester.pumpAndSettle();
    expect(carousel, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
