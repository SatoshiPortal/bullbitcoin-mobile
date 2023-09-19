import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/auth/page.dart';
import 'package:bb_mobile/create/page.dart';
import 'package:bb_mobile/home/home_page.dart';
import 'package:bb_mobile/import/page.dart';
import 'package:bb_mobile/receive/wallet_select.dart';
import 'package:bb_mobile/send/wallet_select.dart';
import 'package:bb_mobile/settings/settings_page.dart';
import 'package:bb_mobile/transaction/transaction_page.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/accounting.dart';
import 'package:bb_mobile/wallet_settings/wallet_settings_page.dart';
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) {
        return const AuthPage(fromSettings: false);
      },
    ),
    GoRoute(
      path: '/change-pin',
      builder: (context, state) {
        return const AuthPage(fromSettings: true);
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        return const HomePage();
      },
    ),
    GoRoute(
      path: '/create-wallet',
      builder: (context, state) {
        return const CreateWalletPage();
      },
    ),
    GoRoute(
      path: '/import',
      builder: (context, state) {
        return const ImportWalletPage();
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) {
        return const SettingsPage();
      },
    ),
    GoRoute(
      path: '/tx',
      builder: (context, state) {
        final tx = state.extra! as Transaction;
        return TxPage(tx: tx);
      },
    ),
    GoRoute(
      path: '/wallet-settings',
      builder: (context, state) {
        return const WalletSettingsPage();
      },
    ),
    GoRoute(
      path: '/wallet-settings/test-backup',
      builder: (context, state) {
        return const WalletSettingsPage(openTestBackup: true);
      },
    ),
    GoRoute(
      path: '/wallet-settings/accounting',
      builder: (context, state) {
        final walletBloc = state.extra! as WalletBloc;
        return AccountingPage(walletBloc: walletBloc);
      },
    ),
    GoRoute(
      path: '/send',
      builder: (context, state) {
        // final String? deepLinkUri = state.extra as String?;

        return const SelectSendWalletPage();
      },
    ),
    GoRoute(
      path: '/receive',
      builder: (context, state) {
        return const SelectReceiveWalletPage();
      },
    ),
  ],
);
