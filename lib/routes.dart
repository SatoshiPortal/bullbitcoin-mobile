import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_ui/logger_page.dart';
import 'package:bb_mobile/auth/page.dart';
import 'package:bb_mobile/create/page.dart';
import 'package:bb_mobile/home/home_page.dart';
import 'package:bb_mobile/home/market.dart';
import 'package:bb_mobile/home/transactions.dart';
import 'package:bb_mobile/import/page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/receive/receive_page.dart';
// import 'package:bb_mobile/seeds/seeds_page.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/settings/application_settings_page.dart';
import 'package:bb_mobile/settings/bitcoin_settings_page.dart';
import 'package:bb_mobile/settings/broadcast.dart';
import 'package:bb_mobile/settings/core_wallet_settings_page.dart';
import 'package:bb_mobile/settings/settings_page.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:bb_mobile/transaction/transaction_page.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet/details.dart';
import 'package:bb_mobile/wallet/wallet_page.dart';
import 'package:bb_mobile/wallet_settings/accounting.dart';
import 'package:bb_mobile/wallet_settings/backup.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:bb_mobile/wallet_settings/test-backup.dart';
import 'package:bb_mobile/wallet_settings/wallet_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final navigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  observers: [GoRouterObserver()],
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
        // return const HomePage2();
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
    // GoRoute(
    //   path: '/seed-view',
    //   builder: (context, state) {
    //     return const SeedViewPage();
    //   },
    // ),
    GoRoute(
      path: '/create-wallet-main',
      builder: (context, state) {
        return const CreateWalletPage(mainWallet: true);
      },
    ),
    GoRoute(
      path: '/import-main',
      builder: (context, state) {
        return const ImportWalletPage(mainWallet: true);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) {
        return const SettingsPage();
      },
    ),
    GoRoute(
      path: '/bitcoin-settings',
      builder: (context, state) {
        return const BitcoinSettingsPage();
      },
    ),
    GoRoute(
      path: '/application-settings',
      builder: (context, state) {
        return const ApplicationSettingsPage();
      },
    ),
    GoRoute(
      path: '/core-wallet-settings',
      builder: (context, state) {
        return const CoreWalletSettingsPage();
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
        final walletBloc = state.extra! as WalletBloc;
        return WalletSettingsPage(walletBloc: walletBloc);
      },
    ),
    // GoRoute(
    //   path: '/wallet-settings/open-test-backup',
    //   builder: (context, state) {
    //     return const WalletSettingsPage(openTestBackup: true);
    //   },
    // ),
    GoRoute(
      path: '/wallet-settings/open-backup',
      builder: (context, state) {
        final walletBloc = state.extra! as WalletBloc;
        return WalletSettingsPage(openBackup: true, walletBloc: walletBloc);
      },
    ),
    GoRoute(
      path: '/wallet-settings/test-backup',
      builder: (context, state) {
        final blocs = state.extra! as (WalletBloc, WalletSettingsCubit);
        return TestBackupPage(
          walletBloc: blocs.$1,
          walletSettings: blocs.$2,
        );
        // const WalletSettingsPage(openTestBackup: true);
      },
    ),
    GoRoute(
      path: '/wallet-settings/backup',
      builder: (context, state) {
        final blocs = state.extra! as (WalletBloc, WalletSettingsCubit);

        return BackupPage(
          walletBloc: blocs.$1,
          walletSettings: blocs.$2,
        );
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
        final String? deepLinkUri = state.extra as String?;
        final openscanner = deepLinkUri != null && deepLinkUri == 'scan';

        return SendPage(openScanner: openscanner);
      },
    ),
    GoRoute(
      path: '/receive',
      builder: (context, state) {
        final walletBloc = state.extra as WalletBloc?;

        return ReceivePage(walletBloc: walletBloc);
      },
    ),

    GoRoute(
      path: '/swap-receive',
      builder: (context, state) {
        final tx = state.extra! as SwapTx;
        return ReceivingSwapPage(tx: tx);
      },
    ),
    GoRoute(
      path: '/wallet',
      builder: (context, state) {
        final wallet = state.extra! as WalletBloc;
        return WalletPage(walletBloc: wallet);
      },
    ),
    GoRoute(
      path: '/wallet/details',
      builder: (context, state) {
        final wallet = state.extra! as WalletBloc;
        return WalletDetailsPage(walletBloc: wallet);
      },
    ),
    GoRoute(
      path: '/logs',
      builder: (context, state) {
        return const LoggerPage();
      },
    ),
    GoRoute(
      path: '/market',
      builder: (context, state) {
        return const MarketHome();
      },
    ),
    GoRoute(
      path: '/broadcast',
      builder: (context, state) {
        return const BroadcastPage();
      },
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) {
        return const TransactionHistoryPage();
      },
    ),
  ],
);

class BBlocObserver extends BlocObserver {
  // @override
  // void onEvent(Bloc bloc, Object? event) {
  //   super.onEvent(bloc, event);
  //   debugPrint('\n\n' + event.runtimeType.toString());
  // }

  // @override
  // void onChange(BlocBase bloc, Change change) {
  //   super.onChange(bloc, change);
  //   // debugPrint('\n\n' + change.toString());
  // }

  // @override
  // void onCreate(BlocBase bloc) {
  //   super.onCreate(bloc);
  //   // debugPrint('\n\n' + bloc.toString());
  // }

  // @override
  // void onTransition(Bloc bloc, Transition transition) {
  //   super.onTransition(bloc, transition);
  //   // debugPrint('\n\n' + transition.toString());
  // }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    locator<Logger>().log(
      error.toString() + '\n' + stackTrace.toString(),
      printToConsole: true,
    );
    super.onError(bloc, error, stackTrace);
  }
}

class GoRouterObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    locator<NavName>().update(route.settings.name!);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    locator<NavName>().update(previousRoute!.settings.name!);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('didRemove: $route');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    locator<NavName>().update(newRoute!.settings.name!);
  }
}

class NavName extends Cubit<String> {
  NavName() : super('');

  void update(String name) {
    print('nav: $name');
    emit(name);
  }
}

extension GoRouterExtension on GoRouter {
  String location() {
    final lastMatch = routerDelegate.currentConfiguration.last;
    final matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    final String location = matchList.uri.toString();
    return location;
  }
}
