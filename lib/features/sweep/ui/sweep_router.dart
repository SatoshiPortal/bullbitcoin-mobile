import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/sweep/presentation/sweep_cubit.dart';
import 'package:bb_mobile/features/sweep/ui/screens/sweep_screen.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What the Coins screen hands to the sweep flow: the wallet the coins belong
/// to and the exact coins to spend.
class SweepArgs {
  final Wallet wallet;
  final List<WalletUtxo> inputs;

  const SweepArgs({required this.wallet, required this.inputs});
}

enum SweepRoute {
  sweep('/sweep');

  const SweepRoute(this.path);

  final String path;
}

class SweepRouter {
  static final route = GoRoute(
    name: SweepRoute.sweep.name,
    path: SweepRoute.sweep.path,
    redirect: (context, state) {
      final args = state.extra;
      // A sweep only means something with coins to sweep, on a Bitcoin wallet.
      // Deep-link or refresh without them → home rather than a force-unwrap
      // crash.
      if (args is! SweepArgs ||
          args.inputs.isEmpty ||
          !args.wallet.isBitcoin ||
          !args.wallet.signsLocally) {
        return WalletRoute.walletHome.path;
      }
      return null;
    },
    builder: (context, state) {
      final args = state.extra! as SweepArgs;
      return BlocProvider(
        create: (_) => locator<SweepCubit>(param1: args)..init(),
        child: const SweepScreen(),
      );
    },
  );
}
