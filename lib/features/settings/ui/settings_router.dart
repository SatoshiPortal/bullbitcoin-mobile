import 'package:bb_mobile/features/address_view/presentation/address_view_bloc.dart';
import 'package:bb_mobile/features/address_view/ui/screens/addresses_screen.dart';
import 'package:bb_mobile/features/backup_settings/ui/backup_settings_router.dart';
import 'package:bb_mobile/features/backup_settings/ui/screens/backup_settings_screen.dart';
import 'package:bb_mobile/features/backup_wallet/ui/backup_wallet_router.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/legacy_seed_view/presentation/legacy_seed_view_cubit.dart';
import 'package:bb_mobile/features/legacy_seed_view/ui/legacy_seed_view_screen.dart';
import 'package:bb_mobile/features/pin_code/ui/pin_code_setting_flow.dart';
import 'package:bb_mobile/features/settings/ui/screens/all_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/app_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/app_settings/log_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/bitcoin_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_details_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_options_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallets_list_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/currency/currency_settings_screen.dart';

import 'package:bb_mobile/features/settings/ui/screens/exchange/account_info_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/app_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/bitcoin_wallets_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/exchange_account_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/exchange_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/file_upload_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/legacy_transactions_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/logout_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/recipients_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/referrals_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/security_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/exchange/transactions_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/language/language_settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/widgets/failed_wallet_deletion_alert_dialog.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
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
  walletOptions(':walletId/options'),
  walletAddresses(':walletId/addresses'),
  logs('logs'),
  legacySeeds('legacy-seeds'),
  experimental('experimental-settings'),
  exchangeAccount('exchange-account'),
  exchangeSettings('exchange-settings'),
  exchangeAccountInfo('exchange-account-info'),
  exchangeSecurity('exchange-security'),
  exchangeBitcoinWallets('exchange-bitcoin-wallets'),
  exchangeAppSettings('exchange-app-settings'),
  exchangeFileUpload('exchange-file-upload'),
  exchangeTransactions('exchange-transactions'),
  exchangeLegacyTransactions('exchange-legacy-transactions'),
  exchangeRecipients('exchange-recipients'),
  exchangeReferrals('exchange-referrals'),
  exchangeLogout('exchange-logout'),
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
        name: SettingsRoute.exchangeSettings.name,
        path: SettingsRoute.exchangeSettings.path,

        builder:
            (context, state) => BlocListener<ExchangeCubit, ExchangeState>(
              listenWhen:
                  (previous, current) =>
                      !previous.notLoggedIn && current.notLoggedIn,
              listener: (context, state) {
                // Redirect to auth screen if the user logged out
                context.goNamed(ExchangeRoute.exchangeAuth.name);
              },
              child: const ExchangeSettingsScreen(),
            ),
      ),
      GoRoute(
        name: SettingsRoute.exchangeAccountInfo.name,
        path: SettingsRoute.exchangeAccountInfo.path,
        builder: (context, state) => const ExchangeAccountInfoScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeSecurity.name,
        path: SettingsRoute.exchangeSecurity.path,
        builder: (context, state) => const ExchangeSecurityScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeBitcoinWallets.name,
        path: SettingsRoute.exchangeBitcoinWallets.path,
        builder: (context, state) => const ExchangeBitcoinWalletsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeAppSettings.name,
        path: SettingsRoute.exchangeAppSettings.path,
        builder: (context, state) => const ExchangeAppSettingsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeFileUpload.name,
        path: SettingsRoute.exchangeFileUpload.path,
        builder: (context, state) => const ExchangeFileUploadScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeTransactions.name,
        path: SettingsRoute.exchangeTransactions.path,
        builder: (context, state) => const ExchangeTransactionsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeLegacyTransactions.name,
        path: SettingsRoute.exchangeLegacyTransactions.path,
        builder: (context, state) => const ExchangeLegacyTransactionsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeRecipients.name,
        path: SettingsRoute.exchangeRecipients.path,
        builder: (context, state) => const ExchangeRecipientsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeReferrals.name,
        path: SettingsRoute.exchangeReferrals.path,
        builder: (context, state) => const ExchangeReferralsScreen(),
      ),
      GoRoute(
        name: SettingsRoute.exchangeLogout.name,
        path: SettingsRoute.exchangeLogout.path,
        builder: (context, state) => const ExchangeLogoutScreen(),
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
            path: SettingsRoute.walletOptions.path,
            name: SettingsRoute.walletOptions.name,
            builder: (context, state) {
              final walletId = state.pathParameters['walletId']!;
              return WalletOptionsScreen(walletId: walletId);
            },
          ),
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
          GoRoute(
            path: SettingsRoute.walletAddresses.path,
            name: SettingsRoute.walletAddresses.name,
            builder: (context, state) {
              final walletId = state.pathParameters['walletId']!;
              return BlocProvider(
                create:
                    (_) =>
                        locator<AddressViewBloc>(param1: walletId, param2: 10),
                child: AddressesScreen(walletId: walletId),
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
    ],
  );
}
