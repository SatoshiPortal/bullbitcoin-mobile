import 'package:bull_ui/bull_ui.dart' show BuildContext, SizedBox, Widget;
import 'package:bb_mobile/features/settings/ui/screens/exchange/exchange_access_settings_screen.dart';
import 'package:bb_mobile/features/settings/presentation/exchange_access_settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/quick_actions_settings_screen.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:bb_mobile/features/address_view/ui/screens/addresses_screen.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/features/all_seed_view/ui/all_seed_view_screen.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_swap_rescue_wallets_usecase.dart';
import 'package:bb_mobile/features/autoswap/ui/screens/autoswap_settings_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/public/exchange_settings_facade.dart';
import 'package:bb_mobile/features/pin_code/ui/pin_code_setting_flow.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/pay/public/pay_facade.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/all_settings_screen.dart';
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
import 'package:bb_mobile/features/settings/ui/screens/settings_search_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_route.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_deletion_failed_sheet.dart';
import 'package:network/network.dart';
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
  static GoRoute route({
    required Widget Function(BuildContext) buildPriceHistory,
    required void Function(BuildContext) onBackupTestSucceeded,
  }) => GoRoute(
    name: SettingsRoute.settings.name,
    path: SettingsRoute.settings.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<ServiceStatusCubit>()..checkStatus(),
      child: const AllSettingsScreen(),
    ),
    routes: [
      GoRoute(
        name: SettingsRoute.priceHistory.name,
        path: SettingsRoute.priceHistory.path,
        builder: (context, state) => buildPriceHistory(context),
      ),
      GoRoute(
        name: SettingsRoute.search.name,
        path: SettingsRoute.search.path,
        builder: (context, state) => const SettingsSearchScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeAccess.name,
        path: SettingsRoute.exchangeAccess.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<ExchangeAccessSettingsCubit>(),
          child: ExchangeAccessSettingsScreen(
            onBack: () => context.pop(),
            onAuthenticate: () => context.pushNamed<void>(
              ExchangeRoute.exchangeAuth.name,
              queryParameters: {'from': 'settings'},
            ),
            onOpenAccount: () =>
                context.pushNamed(ExchangeSettingsRoute.home.name),
            onDisabled: () => context.goNamed(WalletRoute.walletHome.name),
          ),
        ),
      ),
      GoRoute(
        name: SettingsRoute.quickActions.name,
        path: SettingsRoute.quickActions.path,
        builder: (context, state) =>
            QuickActionsSettingsScreen(cubit: locator<QuickActionsCubit>()),
      ),
      DefaultWalletsRouter.route,
      ...ExchangeSettingsRouter.routes(
        ExchangeSettingsRouterConfig(
          isSuperuser: (context) =>
              context.select(
                (SettingsCubit cubit) => cubit.state.isSuperuser,
              ) ??
              false,
          isTestnet: (context) => switch (context.select(
            (SettingsCubit cubit) => cubit.state.environment,
          )) {
            null || Environment.regtest => null,
            final environment => environment.requireHistoricalTestnet(),
          },
          onOpenRecipients: (context) => context.pushNamed(PayRoute.pay.name),
          onOpenTransactions: (context) =>
              context.pushNamed(TransactionsRoute.exchangeTransactions.name),
          onOpenDefaultWallets: (context) =>
              context.pushNamed(DefaultWalletsRoute.defaultWallets.name),
        ),
      ),
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
          TorSettingsRouter.route,
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

      GoRoute(
        path: SettingsRoute.pinCode.path,
        name: SettingsRoute.pinCode.name,
        builder: (context, state) => const PinCodeSettingFlow(),
      ),
      GoRoute(
        path: SettingsRoute.backupSettings.path,
        name: SettingsRoute.backupSettings.name,
        builder: (context, state) => const BackupSettingsScreen(),
        routes: [
          BackupSettingsSettingsRouter.route,
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
      GoRoute(
        path: SettingsRoute.allSeedView.path,
        name: SettingsRoute.allSeedView.name,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<AllSeedViewCubit>(),
          child: const AllSeedViewScreen(appUnlockFacade: AppUnlockFacade()),
        ),
      ),
    ],
  );
}
