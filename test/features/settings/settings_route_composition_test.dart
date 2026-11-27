import 'package:bb_mobile/localizations.dart';
import 'package:bb_mobile/router.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:network/network.dart' show NoDefaultWalletFailure;
import 'package:network/testing.dart';
import 'package:overview/overview.dart';
import 'package:settings/settings.dart';

GoRoute _marker(String route) => GoRoute(
  name: route,
  path: route,
  builder: (_, _) => throw StateError('Unexpected build of $route'),
);

final class _Storage implements QuickActionsStorage {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}
}

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
    final actions = createQuickActionsCubit(
      storage: _Storage(),
      warning: (_) {},
      exchangeVisible: const Stream.empty(),
    );
    final prompt = createExchangePromptCubit(
      storage: _Storage(),
      warning: (_) {},
      offered: const Stream.empty(),
    );
    addTearDown(actions.close);
    addTearDown(prompt.close);
    var resolutions = 0;
    final children = AppRouter.settingsChildren(
      quickActions: () {
        resolutions++;
        return actions;
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
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: WalletQuickActions(
              quickActions: actions,
              onAction: (_, _) {},
              onCustomize: AppRouter.customizeQuickActions,
              exchangePrompt: prompt,
              onActivateExchange: (_) {},
            ),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SizedBox(),
          routes: children,
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
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
    );
    await tester.pumpAndSettle();
    expect(resolutions, 0);
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
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
