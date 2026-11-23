import 'dart:io';

import 'package:bull_ui/bull_ui.dart' show SizedBox, Widget;
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_swap_rescue_wallets_usecase.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_failure_l10n.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_scope.dart';
import 'package:bb_mobile/features/exchange/ui/default_wallets_payout_binding.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_rescue_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/swap_restore_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/swap_rescue_details_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/swap_restore_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_details_screen.dart';
import 'package:settings/settings.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_deletion_failed_sheet.dart';
import 'package:transactions/routes.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:bull_logs/bull_logs.dart';
import 'package:bb_mobile/features/settings/presentation/wallet_discovery_cubit.dart';

class SettingsRouter {
  static Widget menuScope(Widget child) => ExchangeAccessBuilder(
    builder: (_, access) =>
        RepositoryProvider<ExchangeAccess>.value(value: access, child: child),
  );

  static final exchangeSettingsHost = ExchangeSettingsHost(
    exchange: () => locator<Exchange>(),
    savePreferences: ({language, currency, emailNotificationsEnabled}) =>
        locator<Exchange>().updateCurrentPreferences(
          language: language,
          currency: currency,
          emailNotificationsEnabled: emailNotificationsEnabled,
        ),
    refreshSession: ExchangeSessionScope.refresh,
    isLoggedIn: ExchangeScope.isLoggedIn,
    sessionChanges: ExchangeScope.signedInChanges,
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
        context.goNamed(ExchangeRoute.exchangeHome.name),
    access: (
      actions: (
        current: () => locator<Exchange>().currentAccess,
        watch: () => locator<Exchange>().watchAccess(),
        enable: () => locator<Exchange>().enableAccess(),
        signOut: () => locator<Exchange>().signOut(),
        resolve: () => locator<Exchange>().resolveAccess(),
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
    required List<RouteBase> accessRoutes,
    RouteBase? seedViewRoute,
    required List<RouteBase> exchangeSettingsRoutes,
    List<RouteBase> addressRoutes = const [],
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

      ...accessRoutes,
      ...backupRoutes,
      // A wallet is always reached from its own screen (wallet home → gear),
      // never from a list, so these carry the shared prefix themselves.
      GoRoute(
        path: SettingsRoute.walletDetailsSelectedWallet.path,
        name: SettingsRoute.walletDetailsSelectedWallet.name,
        builder: (context, state) {
          final walletId = state.pathParameters['walletId']!;
          return MultiBlocListener(
            listeners: [
              BlocListener<WalletBloc, WalletState>(
                listenWhen: (previous, current) {
                  return previous.wallets.length > current.wallets.length;
                },
                listener: (context, state) {
                  context.goNamed(WalletRoute.walletHome.name);
                },
              ),
              BlocListener<WalletBloc, WalletState>(
                listenWhen: (previous, current) {
                  // Listen for a wallet deletion failure to show a sheet.
                  return previous.walletDeletionFailure == null &&
                      current.walletDeletionFailure != null;
                },
                listener: (context, state) {
                  WalletDeletionFailedSheet.show(
                    context,
                    failure: state.walletDeletionFailure!,
                  );
                },
              ),
            ],
            child: BlocProvider(
              create: (_) => locator<WalletDiscoveryCubit>(),
              child: WalletDetailsScreen(walletId: walletId),
            ),
          );
        },
      ),
      ...addressRoutes,
      const LogsFeature().route,
      ?seedViewRoute,
    ];
  }
}
