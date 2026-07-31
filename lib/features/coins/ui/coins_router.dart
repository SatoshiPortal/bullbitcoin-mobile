import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:bb_mobile/features/coins/ui/screens/coins_screen.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum CoinsRoute {
  coins('/coins');

  const CoinsRoute(this.path);

  final String path;
}

class CoinsRouter {
  static final route = GoRoute(
    name: CoinsRoute.coins.name,
    path: CoinsRoute.coins.path,
    redirect: (context, state) {
      // Deep-link / refresh with no wallet in `extra` → fall back to home
      // rather than force-unwrap-crash.
      if (state.extra is! Wallet) {
        return WalletRoute.walletHome.path;
      }
      return null;
    },
    builder: (context, state) {
      final wallet = state.extra! as Wallet;
      return BlocProvider(
        create: (_) => locator<CoinsCubit>(param1: wallet.id)..load(),
        child: CoinsScreen(wallet: wallet),
      );
    },
  );
}
