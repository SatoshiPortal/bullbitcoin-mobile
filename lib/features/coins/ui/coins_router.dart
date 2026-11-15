import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart' show Outpoint;
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:bb_mobile/features/coins/ui/screens/coins_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

typedef OpenSelectedCoinsFlow = Future<void> Function(
  BuildContext context,
  Wallet wallet,
  Set<Outpoint> outpoints,
);

enum CoinsRoute {
  coins('/coins');

  const CoinsRoute(this.path);

  final String path;
}

class CoinsRouter {
  static GoRoute route({
    required String missingWalletRedirect,
    required OpenSelectedCoinsFlow onSend,
    required OpenSelectedCoinsFlow onSweep,
  }) => GoRoute(
    name: CoinsRoute.coins.name,
    path: CoinsRoute.coins.path,
    redirect: (context, state) {
      // Deep-link / refresh with no wallet in `extra` → fall back to home
      // rather than force-unwrap-crash.
      if (state.extra is! Wallet) {
        return missingWalletRedirect;
      }
      return null;
    },
    builder: (context, state) {
      final wallet = state.extra;
      if (wallet is! Wallet) {
        return const SizedBox.shrink();
      }
      return BlocProvider(
        create: (_) => locator<CoinsCubit>(param1: wallet.id)..load(),
        child: CoinsScreen(
          onSend: (outpoints) => onSend(context, wallet, outpoints),
          onSweep: (outpoints) => onSweep(context, wallet, outpoints),
        ),
      );
    },
  );
}
