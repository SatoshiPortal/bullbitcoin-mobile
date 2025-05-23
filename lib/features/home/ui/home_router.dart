import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/home/presentation/blocs/home_bloc.dart';
import 'package:bb_mobile/features/home/ui/screens/home_screen.dart';
import 'package:bb_mobile/features/home/ui/screens/home_wallet_screen.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_router.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/swap/ui/swap_router.dart';
import 'package:bb_mobile/features/transactions/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum HomeRoute {
  home('/'),
  walletHome('wallet/:walletId');

  const HomeRoute(this.path);

  final String path;
}

class HomeRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create:
            (_) =>
                locator<HomeBloc>()
                  ..add(const HomeStarted())
                  ..add(const CheckAllWarnings()),
        child: BlocListener<SettingsCubit, SettingsState>(
          listenWhen:
              (previous, current) =>
                  previous.environment != current.environment,
          listener: (context, settings) {
            context.read<HomeBloc>().add(const HomeStarted());
          },
          child: child,
        ),
      );
    },
    routes: [
      GoRoute(
        name: HomeRoute.home.name,
        path: HomeRoute.home.path,
        builder: (context, state) {
          return const HomeScreen();
        },
        routes: [
          HomeRouter.walletRoute,
          KeyServerRouter.route,
          SettingsRouter.route,
          TransactionsRouter.route,
          ReceiveRouter.route,
          SendRouter.route,
          SwapRouter.route,
          SellRouter.route,
          BuyRouter.route,
        ],
      ),
    ],
  );

  static final walletRoute = GoRoute(
    name: HomeRoute.walletHome.name,
    path: HomeRoute.walletHome.path,
    builder: (context, state) {
      final walletId = state.pathParameters['walletId']!;
      return BlocProvider<TransactionsCubit>(
        create: (_) => locator<TransactionsCubit>(param1: walletId)..loadTxs(),
        child: HomeWalletScreen(walletId: walletId),
      );
    },
    routes: [ReceiveRouter.route, SendRouter.route],
  );
}
