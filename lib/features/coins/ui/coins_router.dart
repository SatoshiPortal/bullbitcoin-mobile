import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/coins/presentation/coins_cubit.dart';
import 'package:bb_mobile/features/coins/presentation/proof_of_funds_cubit.dart';
import 'package:bb_mobile/features/coins/ui/screens/coins_screen.dart';
import 'package:bb_mobile/features/coins/ui/screens/prove_funds_screen.dart';
import 'package:bb_mobile/features/coins/ui/screens/verify_funds_screen.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum CoinsRoute {
  coins('/coins'),
  proveFunds('/coins/prove'),
  verifyFunds('/coins/verify');

  const CoinsRoute(this.path);

  final String path;
}

/// Arguments for the prove-funds route: the wallet (for network + key access)
/// and the selected Bitcoin UTXOs to prove.
class ProveFundsArgs {
  final Wallet wallet;
  final List<BitcoinWalletUtxo> utxos;

  const ProveFundsArgs({required this.wallet, required this.utxos});
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
        child: const CoinsScreen(),
      );
    },
  );

  static final proveFundsRoute = GoRoute(
    name: CoinsRoute.proveFunds.name,
    path: CoinsRoute.proveFunds.path,
    redirect: (context, state) =>
        state.extra is! ProveFundsArgs ? WalletRoute.walletHome.path : null,
    builder: (context, state) {
      final args = state.extra! as ProveFundsArgs;
      return BlocProvider(
        create: (_) => locator<ProofOfFundsCubit>(param1: args.wallet),
        child: ProveFundsScreen(selectedUtxos: args.utxos),
      );
    },
  );

  static final verifyFundsRoute = GoRoute(
    name: CoinsRoute.verifyFunds.name,
    path: CoinsRoute.verifyFunds.path,
    redirect: (context, state) =>
        state.extra is! Wallet ? WalletRoute.walletHome.path : null,
    builder: (context, state) {
      final wallet = state.extra! as Wallet;
      return BlocProvider(
        create: (_) => locator<ProofOfFundsCubit>(param1: wallet),
        child: const VerifyFundsScreen(),
      );
    },
  );

  static final routes = [route, proveFundsRoute, verifyFundsRoute];
}
