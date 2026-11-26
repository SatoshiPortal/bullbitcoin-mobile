import 'package:bull_ui/bull_ui.dart' show Widget;
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/settings.dart';
import 'package:transactions/routes.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_logs/bull_logs.dart';

class SettingsRouter {
  static Widget menuScope(Widget child) => ExchangeAccessBuilder(
    exchange: locator<Exchange>(),
    builder: (_, access) =>
        RepositoryProvider<ExchangeAccess>.value(value: access, child: child),
  );

  static final exchangeSettingsHost = ExchangeSettingsHost(
    exchange: () => locator<Exchange>(),
    savePreferences: (patch) =>
        locator<Exchange>().updateCurrentPreferences(patch),
    refreshSession: ExchangeSessionScope.refresh,
    isSuperuser: (context) => Settings.isSuperuserOf(context),
    securityUrl: (context) => switch (Settings.networkOf(context)) {
      null || NetworkEnv.regtest || NetworkEnv.signet => null,
      NetworkEnv.mainnet => Uri.parse(
        ExchangeDefaults.bbAuthUrl,
      ).resolve('/settings'),
      NetworkEnv.testnet => Uri.parse(
        ExchangeDefaults.bbAuthTestUrl,
      ).resolve('/settings'),
    },
    title: (context) => context.loc.settingsExchangeSettingsTitle,
    signedOutMessage: (context) => context.loc.notLoggedInMessage,
    hasAccount: ExchangeSessionScope.watchHasAccount,
    accountFailureMessage: (context, failure) => failure.toTranslated(context),
    onOpenRecipients: (context) => context.pushNamed(PayRoute.pay.name),
    onOpenTransactions: (context) =>
        TransactionsNavigation.openHistory(context, exchangeOnly: true),
    onOpenDefaultWallets: DefaultWalletsNavigation.open,
    onOpenExchange: (context) =>
        context.goNamed(BullExchangeNavigation.dashboardName),
    access: (
      actions: (
        current: () => locator<Exchange>().currentAccess,
        watch: () => locator<Exchange>().watchAccess(),
        enable: () => locator<Exchange>().enableAccess(),
        signOut: () => locator<Exchange>().signOut(),
        resolve: () => locator<Exchange>().resolveAccess(),
      ),
      description: (context) => context.loc.exchangeAccessSettingsDescription,
      onAuthenticate: (context) => context.pushNamed<void>(
        BullExchangeNavigation.authName,
        queryParameters: {'from': 'settings'},
      ),
      onDisabled: (context) => context.goNamed(WalletRoute.walletHome.name),
    ),
    defaultWallets: (
      isAvailable: () async => switch (await locator<Preferences>().fetch()) {
        Ok(:final value) => NetworkCapabilities.supports(
          BitcoinNetwork.fromName(value.environment.name),
          NetworkCapability.exchange,
        ),
        Err() => false,
      },
      unavailableRedirectPath: WalletRoute.walletHome.path,
    ),
  );

  static List<RouteBase> childRoutes({
    RouteBase? autoswapSettingsRoute,
    required List<RouteBase> swapRecoveryRoutes,
    required List<RouteBase> priceRoutes,
    required List<RouteBase> backupRoutes,
    required List<RouteBase> accessRoutes,
    RouteBase? seedViewRoute,
    required List<RouteBase> exchangeSettingsRoutes,
    List<RouteBase> addressRoutes = const [],
    required List<RouteBase> walletRoutes,
  }) {
    return [
      ...priceRoutes,
      GoRoute(
        name: SettingsRoute.quickActions.name,
        path: SettingsRoute.quickActions.path,
        builder: (context, state) => QuickActionsCustomizationScreen(
          cubit: locator<QuickActionsCubit>(),
        ),
      ),
      ...exchangeSettingsRoutes,
      ...swapRecoveryRoutes,
      ?autoswapSettingsRoute,

      ...accessRoutes,
      ...backupRoutes,
      ...walletRoutes,
      ...addressRoutes,
      const LogsFeature().route,
      ?seedViewRoute,
    ];
  }
}
