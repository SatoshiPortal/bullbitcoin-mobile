import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/home/presentation/blocs/home_bloc.dart';
import 'package:bb_mobile/features/home/ui/screens/home_screen.dart';
import 'package:bb_mobile/features/home/ui/screens/home_wallet_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/blocs/transactions_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum HomeRoute {
  home('/'),
  walletHome('wallet/:walletId');

  const HomeRoute(this.path);

  final String path;
}

/// The router for the transactions feature.
class HomeRouter {
  static final route = GoRoute(
    name: HomeRoute.home.name,
    path: HomeRoute.home.path,
    builder: (context, state) {
      return BlocProvider<HomeBloc>(
        create:
            (context) =>
                locator<HomeBloc>()
                  ..add(const CheckAllWarnings())
                  ..add(const HomeStarted()),
        child: BlocListener<SettingsCubit, SettingsEntity?>(
          listenWhen:
              (previous, current) =>
                  previous?.environment != current?.environment,
          listener: (context, settings) {
            context.read<HomeBloc>().add(const HomeStarted());
          },
          child: const HomeScreen(),
        ),
      );
    },
    routes: [
      GoRoute(
        name: HomeRoute.walletHome.name,
        path: HomeRoute.walletHome.path,
        builder: (context, state) {
          final walletId = state.pathParameters['walletId']!;
          final homeBloc = state.extra! as HomeBloc;
          return MultiBlocProvider(
            providers: [
              BlocProvider<HomeBloc>.value(value: homeBloc),
              BlocProvider<TransactionsCubit>(
                create:
                    (_) =>
                        locator<TransactionsCubit>(param1: walletId)..loadTxs(),
              ),
            ],
            child: HomeWalletScreen(walletId: walletId),
          );
        },
      ),
    ],
  );
}
