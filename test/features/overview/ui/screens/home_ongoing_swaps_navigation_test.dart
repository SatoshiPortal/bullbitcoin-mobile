import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/overview_router.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_quick_actions/setup.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullCarousel, bullUiLocalizationsDelegate;
import 'package:bull_ui/testing.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:overview/routes.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Ok;
import 'package:send/send.dart' show Consolidation;
import 'package:swap_feature/swap_feature.dart' show HomeOngoingSwaps;
import 'package:swaps/swaps.dart';
import 'package:transactions/routes.dart';

import '../../support/overview_home_harness.dart';

// Regression test for Home's real public route and its swap navigation.

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

class _Consolidation extends Mock implements Consolidation {}

class _MemoryQuickActionsStorage implements QuickActionsStorage {
  String? value;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async => this.value = value;

  @override
  Future<void> remove(String key) async => value = null;
}

void main() {
  testWidgets('Overview updates notices and pushes the swiped swap details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final h = OverviewHomeHarness();
    final controller = h.controller;
    const display = (
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      hideAmounts: false,
    );
    h.amountPreferences.publish(display);
    h.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('wallet-first', isDefault: true),
      ]),
    );

    final quickActions = QuickActionsFeature.mount(
      storage: _MemoryQuickActionsStorage(),
      warning: (_) {},
      isIOS: false,
      exchangeVisible: () => Stream.value(false),
      exchangeEntry: () => const Stream.empty(),
      exchangeOffered: () => const Stream.empty(),
    );
    addTearDown(quickActions.close);
    locator.pushNewScope();
    locator.registerSingleton<OverviewHomeController>(controller);
    GoRouterState? details;
    final router = GoRouter(
      initialLocation: WalletRoute.walletHome.path,
      routes: [
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            OverviewRouter.walletHomeRoute(
              arkHost: null,
              quickActions: () => quickActions.quickActions,
              exchangePrompt: () => quickActions.exchangePrompt,
              onQuickAction: (_, _) {},
              onCustomizeQuickActions: (_) {},
              onActivateExchange: (_) {},
              watchUnreadSupportMessages: (_) => 0,
              announcements: () => const SizedBox.shrink(),
              networkWalletProvisioning: () =>
                  throw StateError('Unexpected wallet setup'),
            ),
          ],
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
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          RepositoryProvider<Consolidation>.value(value: _Consolidation()),
          BitcoinPriceFixture.prices(
            amountDisplay: display,
            currency: 'CAD',
            bitcoinPrice: 100000,
          ),
          BitcoinPriceFixture.chart(),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: [
            ...appLocalizationsDelegates,
            bullUiLocalizationsDelegate,
            QuickActionsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
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
    h.swaps.result = Ok([first, second]);
    await controller.refresh();
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
    h.swaps.result = const Ok([]);
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(carousel, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await locator.popScope();
    await tester.runAsync(h.close);
  });
}
