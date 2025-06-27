import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_detail_screen.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_screen.dart';
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
    pageBuilder: (context, state) {
      return NoTransitionPage(
        key: state.pageKey,
        child: BlocListener<WalletBloc, WalletState>(
          listenWhen:
              (previous, current) =>
                  !previous.noWalletsFound && current.noWalletsFound,
          listener: (context, state) {
            // If no wallets are found, redirect to the onboarding screen
            //  to allow the user to create or restore a wallet.
            context.goNamed(OnboardingRoute.onboarding.name);
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
      return WalletDetailScreen(walletId: walletId);
    },
  );
}
