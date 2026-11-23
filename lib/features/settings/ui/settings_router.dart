import 'dart:io';

import 'package:bull_ui/bull_ui.dart' show SizedBox;
import 'package:bb_mobile/features/settings/ui/screens/quick_actions_settings_screen.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_swap_rescue_wallets_usecase.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange/ui/default_wallets_payout_binding.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/exchange/public/exchange_defaults.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/app_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/permissions_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/payjoin_advanced_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/payjoin_settings_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_rescue_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_restore_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/swap_rescue_details_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/swap_restore_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:transactions/routes.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/background_preferences_cubit.dart';
import 'package:bb_mobile/locator.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:bull_logs/bull_logs.dart';

export 'package:bb_mobile/features/settings/ui/settings_route.dart';

class SettingsRouter {
  static final exchangeSettingsHost = ExchangeSettingsHost(
    exchange: () => locator<Exchange>(),
    savePreferences: ({language, currency, emailNotificationsEnabled}) =>
        locator<ExchangeFacade>().savePreferences(
          language: language,
          currency: currency,
          emailNotificationsEnabled: emailNotificationsEnabled,
        ),
    refreshSession: ExchangeSessionScope.refresh,
    isLoggedIn: ExchangeScope.isLoggedIn,
    sessionChanges: ExchangeScope.signedInChanges,
    isSuperuser: (context) =>
        context.select((SettingsCubit cubit) => cubit.state.isSuperuser) ??
        false,
    securityUrl: (context) => switch (context.select(
      (SettingsCubit cubit) => cubit.state.environment,
    )) {
      null || Environment.regtest => null,
      Environment.mainnet => Uri.parse(
        ExchangeDefaults.bbAuthUrl,
      ).resolve('/settings'),
      Environment.testnet => Uri.parse(
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
        context.goNamed(ExchangeRoute.exchangeHome.name),
    access: (
      actions: (
        current: () => locator<ExchangeFacade>().currentAccess,
        watch: () => locator<ExchangeFacade>().watchAccess(),
        enable: () => locator<ExchangeFacade>().enable(),
        signOut: () => locator<ExchangeFacade>().logout(),
        resolve: () => locator<ExchangeFacade>().resolveAccess(),
      ),
      platform: Platform.isIOS ? ExchangePlatform.ios : ExchangePlatform.other,
      description: (context) => context.loc.exchangeAccessSettingsDescription,
      onAuthenticate: (context) => context.pushNamed<void>(
        ExchangeRoute.exchangeAuth.name,
        queryParameters: {'from': 'settings'},
      ),
      onDisabled: (context) => context.goNamed(WalletRoute.walletHome.name),
    ),
    defaultWallets: (
      payoutFields: exchangePayoutFields,
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
    required List<RouteBase> priceRoutes,
    required List<RouteBase> backupRoutes,
    required List<RouteBase> appSettingsRoutes,
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
        builder: (context, state) =>
            QuickActionsSettingsScreen(cubit: locator<QuickActionsCubit>()),
      ),
      ...exchangeSettingsRoutes,
      GoRoute(
        name: SettingsRoute.walletSettings.name,
        path: SettingsRoute.walletSettings.path,
        builder: (context, state) => const WalletSettingsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.payjoinSettings.name,
        path: SettingsRoute.payjoinSettings.path,
        builder: (context, state) => const PayjoinSettingsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.payjoinAdvancedSettings.name,
        path: SettingsRoute.payjoinAdvancedSettings.path,
        builder: (context, state) => const PayjoinAdvancedSettingsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.swapRestore.name,
        path: SettingsRoute.swapRestore.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<SwapRestoreCubit>()..restore(),
          child: const SwapRestoreScreen(),
        ),
      ),
      GoRoute(
        name: SettingsRoute.swapRescue.name,
        path: SettingsRoute.swapRescue.path,
        redirect: (context, state) => state.extra is RestorableSwap
            ? null
            : state.namedLocation(SettingsRoute.swapRestore.name),
        builder: (context, state) => switch (state.extra) {
          final RestorableSwap restorable => BlocProvider(
            create: (_) => SwapRescueCubit(
              rescueSwapUsecase: locator<RescueSwapUsecase>(),
              getRescueWalletsUsecase: locator<GetSwapRescueWalletsUsecase>(),
              restored: restorable.swap,
            ),
            child: SwapRescueDetailsScreen(restorable: restorable),
          ),
          _ => const SizedBox.shrink(),
        },
      ),
      ?autoswapSettingsRoute,
      GoRoute(
        name: SettingsRoute.appSettings.name,
        path: SettingsRoute.appSettings.path,
        builder: (context, state) => const AppSettingsScreen(),
        routes: [
          ...appSettingsRoutes,
          GoRoute(
            name: SettingsRoute.permissions.name,
            path: SettingsRoute.permissions.path,
            builder: (context, state) => BlocProvider(
              create: (_) => locator<BackgroundPreferencesCubit>()..load(),
              child: const PermissionsScreen(),
            ),
          ),
        ],
      ),

      ...accessRoutes,
      ...backupRoutes,
      ...walletRoutes,
      ...addressRoutes,
      const LogsFeature().route,
      ?seedViewRoute,
    ];
  }
}
