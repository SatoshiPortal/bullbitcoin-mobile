import 'package:bb_mobile/overview_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:overview/overview.dart';
import 'package:overview/routes.dart';
import 'package:send/send.dart' show Consolidation;
import 'package:mocktail/mocktail.dart';

import '../overview/support/overview_home_harness.dart';

import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/router.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_quick_actions/setup.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:network/network.dart' show NoDefaultWalletFailure;
import 'package:network/testing.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:settings/settings.dart';

GoRoute _marker(String route) => GoRoute(
  name: route,
  path: route,
  builder: (_, _) => throw StateError('Unexpected build of $route'),
);

final class _Storage implements QuickActionsStorage {
  final reads = <String>[];

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    return null;
  }

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}
}

class _Consolidation extends Mock implements Consolidation {}

void main() {
  for (final optional in [false, true]) {
    test(
      'Settings preserves the real route composition (options: $optional)',
      () {
        final exchange = BullExchangeFeature.mount(
          exchange: () => throw StateError('Exchange resolved during mount'),
          preferences: () =>
              throw StateError('Preferences resolved during mount'),
          isSuperuser: (_) =>
              throw StateError('Platform resolved during mount'),
          homePath: '/',
          onExit: AppRouter.exitExchange,
          onOpenSettings: (_) {},
          onAction: (_, _) {},
          brandAssetPath: 'unused',
          settingsAssetPath: 'unused',
          settings: optional
              ? AppRouter.exchangeSettingsHost
              : ExchangeSettingsHost(
                  networkOf: (_) => null,
                  isSuperuser: (_) => false,
                  title: (_) => '',
                  signedOutMessage: (_) => '',
                  onOpenRecipients: (_) {},
                  onOpenTransactions: (_) {},
                ),
        );
        final children = AppRouter.settingsChildren(
          quickActions: () =>
              throw StateError('Quick Actions resolved during mount'),
          priceRoutes: [_marker('price')],
          exchangeSettingsRoutes: exchange.settingsRoutes,
          swapRecoveryRoutes: [
            GoRoute(
              path: 'swap-restore',
              name: 'swapRestore',
              builder: (_, _) => const SizedBox(),
            ),
            GoRoute(
              path: 'swap-rescue',
              name: 'swapRescue',
              builder: (_, _) => const SizedBox(),
            ),
          ],
          autoswapSettingsRoute: optional ? _marker('autoswap') : null,
          accessRoutes: [_marker('access')],
          backupRoutes: [_marker('backup')],
          walletRoutes: [_marker('walletDetail')],
          addressRoutes: optional ? [_marker('address')] : [],
          seedViewRoute: optional ? _marker('seed') : null,
        );
        final hub = SettingsFeature.mount(
          settings: () => throw StateError('Settings resolved during mount'),
          exchange: () =>
              throw StateError('Menu Exchange resolved during mount'),
          status: networkStatusForTest(
            () async => const Err(NoDefaultWalletFailure()),
          ),
          childRoutes: children,
        );
        expect((hub.route.name, hub.route.path), ('settings', '/settings'));
        expect(
          hub.route.routes.cast<GoRoute>().map(
            (route) => (route.name, route.path),
          ),
          [
            ('search', 'search'),
            ('walletSettings', 'bitcoin-settings'),
            ('payjoinSettings', 'payjoin-settings'),
            ('payjoinAdvancedSettings', 'payjoin-advanced-settings'),
            ('appSettings', 'app-settings'),
            ('price', 'price'),
            ('quickActions', 'quick-actions'),
            if (optional) ...[
              ('defaultWallets', 'exchange-bitcoin-wallets'),
              ('exchangeAccess', 'exchange-access'),
            ],
            ('home', 'exchange-settings'),
            ('security', 'exchange-security'),
            ('referrals', 'exchange-referrals'),
            ('accountInfo', 'exchange-account-info'),
            ('preferences', 'exchange-app-settings'),
            ('secureFileUpload', 'secure-file-upload'),
            ('statistics', 'exchange-statistics'),
            ('swapRestore', 'swap-restore'),
            ('swapRescue', 'swap-rescue'),
            if (optional) ('autoswap', 'autoswap'),
            ('access', 'access'),
            ('backup', 'backup'),
            ('walletDetail', 'walletDetail'),
            if (optional) ('address', 'address'),
            ('logs', 'logs'),
            if (optional) ('seed', 'seed'),
          ],
        );
      },
    );
  }

  testWidgets('Wallet customization opens the real route with the same cubit', (
    tester,
  ) async {
    final storage = _Storage();
    var promptFactories = 0;
    final owner = QuickActionsFeature.mount(
      storage: storage,
      warning: (_) {},
      isIOS: false,
      exchangeVisible: () => Stream.value(false),
      exchangeEntry: () => const Stream.empty(),
      exchangeOffered: () {
        promptFactories++;
        return const Stream.empty();
      },
    );
    addTearDown(owner.close);
    var resolutions = 0;
    final children = AppRouter.settingsChildren(
      quickActions: () {
        resolutions++;
        return owner.quickActions;
      },
      priceRoutes: [],
      exchangeSettingsRoutes: [],
      swapRecoveryRoutes: [],
      accessRoutes: [],
      backupRoutes: [],
      walletRoutes: [],
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        ShellRoute(
          builder: (_, _, child) => Scaffold(body: child),
          routes: [
            OverviewRouter.walletHomeRoute(
              arkHost: null,
              quickActions: () => owner.quickActions,
              exchangePrompt: () => owner.exchangePrompt,
              onQuickAction: (_, _) {},
              onCustomizeQuickActions: AppRouter.customizeQuickActions,
              onActivateExchange: (_) {},
              watchUnreadSupportMessages: (_) => 0,
              announcements: () => const SizedBox.shrink(),
              networkWalletProvisioning: () =>
                  throw StateError('Wallet setup not expected'),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SizedBox(),
          routes: children,
        ),
      ],
    );
    addTearDown(router.dispose);
    expect(promptFactories, 0);
    expect(storage.reads, isEmpty);
    await tester.runAsync(owner.preload);
    final actions = owner.quickActions;
    expect(actions.state.initialized, isTrue);
    expect(promptFactories, 0);
    expect(storage.reads, ['quick_actions']);
    final homeHarness = OverviewHomeHarness();
    homeHarness.source.publish(
      snapshot(OverviewCatalogueStatus.ready, [
        homeWallet('settings-wallet', isDefault: true, balanceSat: 1234),
      ]),
    );
    homeHarness.amountPreferences.publish((
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      hideAmounts: false,
    ));
    locator.pushNewScope();
    locator.registerSingleton<OverviewHomeController>(homeHarness.controller);
    addTearDown(() async {
      await locator.popScope();
      await homeHarness.close();
    });
    const display = (
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      hideAmounts: false,
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
          localizationsDelegates: const [
            QuickActionsLocalizations.delegate,
            bullUiLocalizationsDelegate,
            ...appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.themeData(AppThemeType.light),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(resolutions, 0);
    expect(promptFactories, 0);
    router.goNamed(WalletRoute.walletHome.name);
    await tester.pumpAndSettle();
    final home = tester.widget<WalletQuickActions>(
      find.byType(WalletQuickActions),
    );
    expect(home.quickActions, same(actions));
    expect(home.exchangePrompt, same(owner.exchangePrompt));
    expect(promptFactories, 1);
    await tester.longPress(find.text('Swap'));
    await tester.pumpAndSettle();
    final screen = tester.widget<QuickActionsCustomizationScreen>(
      find.byType(QuickActionsCustomizationScreen),
    );
    expect(screen.cubit, same(actions));
    expect(resolutions, greaterThanOrEqualTo(1));
    expect(
      GoRouterState.of(
        tester.element(find.byType(QuickActionsCustomizationScreen)),
      ).uri.path,
      '/settings/quick-actions',
    );
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Swap'), findsOneWidget);
    expect(storage.reads, [
      'quick_actions',
      'quick_actions_exchange_prompt_dismissed',
    ]);
    expect(promptFactories, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
