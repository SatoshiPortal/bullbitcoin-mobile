import 'dart:io';

import 'package:bull_ui/bull_ui.dart' show BuildContext, SizedBox;
import 'package:bb_mobile/features/settings/ui/screens/quick_actions_settings_screen.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:bb_mobile/features/address_view/ui/screens/addresses_screen.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_swap_rescue_wallets_usecase.dart';
import 'package:bb_mobile/features/autoswap/ui/screens/autoswap_settings_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_options_bindings.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange/ui/default_wallets_payout_binding.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/exchange/public/exchange_defaults.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/pay/public/pay_facade.dart';
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
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_details_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_deletion_failed_sheet.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/features/transactions/public/transactions_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/background_preferences_cubit.dart';
import 'package:bb_mobile/locator.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:bull_logs/bull_logs.dart';
import 'package:bb_mobile/features/settings/presentation/wallet_discovery_cubit.dart';

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
        context.pushNamed(TransactionsRoute.exchangeTransactions.name),
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
    required List<RouteBase> priceRoutes,
    required void Function(BuildContext) onBackupTestSucceeded,
    required List<RouteBase> appSettingsRoutes,
    required List<RouteBase> accessRoutes,
    RouteBase? seedViewRoute,
    required List<RouteBase> exchangeSettingsRoutes,
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
      GoRoute(
        name: SettingsRoute.autoswapSettings.name,
        path: SettingsRoute.autoswapSettings.path,
        builder: (context, state) => const AutoSwapSettingsScreen(),
      ),
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
      GoRoute(
        path: SettingsRoute.backupSettings.path,
        name: SettingsRoute.backupSettings.name,
        builder: (context, state) => const BackupSettingsScreen(),
        routes: [
          BackupOptionsBindings.mount().route,
          TestWalletBackupRouter.route(onTestSucceeded: onBackupTestSucceeded),
        ],
      ),
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
      GoRoute(
        path: SettingsRoute.walletAddresses.path,
        name: SettingsRoute.walletAddresses.name,
        builder: (context, state) {
          final walletId = state.pathParameters['walletId']!;
          return BlocProvider(
            create: (_) =>
                locator<AddressViewBloc>(param1: walletId, param2: 10),
            child: AddressesScreen(walletId: walletId),
          );
        },
      ),
      const LogsFeature().route,
      ?seedViewRoute,
    ];
  }
}
