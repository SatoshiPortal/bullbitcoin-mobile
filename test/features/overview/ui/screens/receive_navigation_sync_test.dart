import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/overview_router.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_quick_actions/setup.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:overview/routes.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:send/send.dart' show Consolidation;

import '../../support/overview_home_harness.dart';

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
  testWidgets('pushing Receive never requests a sync; returning home does', (
    tester,
  ) async {
    final home = OverviewHomeHarness();
    final controller = home.controller;
    home.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('receive-home', isDefault: true),
      ]),
    );
    home.amountPreferences.publish((
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      hideAmounts: false,
    ));
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
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/receive/bitcoin',
              builder: (_, _) => const Text('Receive'),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          RepositoryProvider<Consolidation>.value(value: _Consolidation()),
          BitcoinPriceFixture.prices(loadingPrice: true),
          BitcoinPriceFixture.chart(),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(home.sync.triggers, [SyncTrigger.automatic]);
    home.sync.triggers.clear();
    router.push<void>('/receive/bitcoin');
    await tester.pumpAndSettle();
    expect(find.text('Receive'), findsOneWidget);
    expect(home.sync.triggers, isEmpty);
    router.pop();
    await tester.pumpAndSettle();
    expect(home.sync.triggers, [SyncTrigger.automatic]);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await locator.popScope();
    await tester.runAsync(home.close);
  });
}
