import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/blocs/detail/wallet_detail_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/blocs/home/wallet_home_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_detail_screen.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum WalletRoute {
  walletHome('/wallet'),
  walletDetail('/wallet/:walletId');

  const WalletRoute(this.path);

  final String path;
}

class WalletRouter {
  static final walletHomeRoute = GoRoute(
    name: WalletRoute.walletHome.name,
    path: WalletRoute.walletHome.path,
    builder: (context, state) {
      return BlocProvider(
        create:
            (_) =>
                locator<WalletHomeBloc>()
                  ..add(const WalletHomeStarted())
                  ..add(const CheckAllWarnings()),
        child: BlocListener<SettingsCubit, SettingsState>(
          listenWhen:
              (previous, current) =>
                  previous.environment != current.environment,
          listener: (context, settings) {
            context.read<WalletHomeBloc>().add(const WalletHomeStarted());
          },
          child: const WalletHomeScreen(),
        ),
      );
    },
  );

  static final walletDetailRoute = GoRoute(
    name: WalletRoute.walletDetail.name,
    path: WalletRoute.walletDetail.path,
    builder: (context, state) {
      final walletId = state.pathParameters['walletId']!;
      return BlocProvider(
        create:
            (_) =>
                locator<WalletDetailBloc>(param1: walletId)
                  ..add(const WalletDetailEvent.started()),
        child: const WalletDetailScreen(),
      );
    },
  );
}
