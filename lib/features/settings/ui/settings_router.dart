import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/features/backup_wallet/ui/backup_wallet_router.dart';
import 'package:bb_mobile/features/experimental/experimental_router.dart';
import 'package:bb_mobile/features/legacy_seed_view/presentation/legacy_seed_view_cubit.dart';
import 'package:bb_mobile/features/legacy_seed_view/ui/legacy_seed_view_screen.dart';
import 'package:bb_mobile/features/pin_code/ui/pin_code_setting_flow.dart';
import 'package:bb_mobile/features/settings/ui/screens/all_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/app_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/log_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/bitcoin_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/experimental_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_details_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallets_list_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/currency/currency_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/exchange_account_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/language/language_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/widgets/failed_wallet_deletion_alert_dialog.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SettingsRoute {
  settings('/settings'),
  pinCode('pin-code'),
  language('language'),
  currency('currency'),
  backupSettings('backup-settings'),
  walletDetailsWalletList('wallet-details'),
  walletDetailsSelectedWallet(':walletId'),
  logs('logs'),
  legacySeeds('legacy-seeds'),
  experimental('experimental-settings'),
  exchangeAccount('exchange-account'),
  bitcoinSettings('bitcoin-settings'),
  appSettings('app-settings');

  final String path;

  const SettingsRoute(this.path);
}

class SettingsRouter {
  static final route = GoRoute(
    name: SettingsRoute.settings.name,
    path: SettingsRoute.settings.path,
    builder: (context, state) => const AllSettingsScreen(),
    routes: [
      GoRoute(
        name: SettingsRoute.exchangeAccount.name,
        path: SettingsRoute.exchangeAccount.path,
        builder: (context, state) => const ExchangeAccountScreen(),
      ),
      GoRoute(
        name: SettingsRoute.bitcoinSettings.name,
        path: SettingsRoute.bitcoinSettings.path,
        builder: (context, state) => const BitcoinSettingsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.appSettings.name,
        path: SettingsRoute.appSettings.path,
        builder: (context, state) => const AppSettingsScreen(),
      ),

      GoRoute(
        name: SettingsRoute.language.name,
        path: SettingsRoute.language.path,
        builder: (context, state) => const LanguageSettingsScreen(),
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
          ...BackupSettingsSettingsRouter.routes,
          ...BackupWalletRouter.routes,
          ...TestWalletBackupRouter.routes,
        ],
      ),
      GoRoute(
        path: SettingsRoute.walletDetailsWalletList.path,
        name: SettingsRoute.walletDetailsWalletList.name,
        builder: (context, state) => const WalletsListScreen(),
        routes: [
          GoRoute(
            path: SettingsRoute.walletDetailsSelectedWallet.path,
            name: SettingsRoute.walletDetailsSelectedWallet.name,
            builder: (context, state) {
              final walletId = state.pathParameters['walletId']!;
              return MultiBlocListener(
                listeners: [
                  BlocListener<WalletBloc, WalletState>(
                    listenWhen: (previous, current) {
                      // Listen for wallet deletion to go back to the wallet list
                      return previous.wallets.length > current.wallets.length;
                    },
                    listener: (context, state) {
                      context.pop();
                    },
                  ),
                  BlocListener<WalletBloc, WalletState>(
                    listenWhen: (previous, current) {
                      // Listen for wallet deletion error to show an alert dialog
                      return previous.walletDeletionError == null &&
                          current.walletDeletionError != null;
                    },
                    listener: (context, state) {
                      showDialog(
                        context: context,
                        builder:
                            (dialogContext) =>
                                const FailedWalletDeletionAlertDialog(),
                      );
                    },
                  ),
                ],
                child: WalletDetailsScreen(walletId: walletId),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: SettingsRoute.logs.path,
        name: SettingsRoute.logs.name,
        builder: (context, state) => const LogSettingsScreen(),
      ),
      GoRoute(
        path: SettingsRoute.legacySeeds.path,
        name: SettingsRoute.legacySeeds.name,
        builder:
            (context, state) => BlocProvider(
              create: (_) => locator<LegacySeedViewCubit>(),
              child: const LegacySeedViewScreen(),
            ),
      ),
      GoRoute(
        path: SettingsRoute.currency.path,
        name: SettingsRoute.currency.name,
        builder: (context, state) => const CurrencySettingsScreen(),
      ),
      GoRoute(
        path: SettingsRoute.experimental.path,
        name: SettingsRoute.experimental.name,
        builder: (context, state) => const ExperimentalSettingsScreen(),
        routes: [ExperimentalRouterConfig.route],
      ),
    ],
  );
}
