import 'package:primitives/primitives.dart' show Outpoint;
import 'package:coins/src/presentation/coins_cubit.dart';
import 'package:coins/src/ui/screens/coins_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

typedef OpenSelectedCoinsFlow<T extends Object> = Future<void> Function(
  BuildContext context,
  T wallet,
  Set<Outpoint> outpoints,
);

const coinsRouteName = 'coins';

GoRoute coinsRoute<T extends Object>({
  required String Function(T) walletId,
  required CoinsCubit Function(String) createCubit,
  required String missingWalletRedirect,
  required OpenSelectedCoinsFlow<T> onSend,
  required OpenSelectedCoinsFlow<T> onSweep,
}) => GoRoute(
  name: coinsRouteName,
  path: '/coins',
  redirect: (context, state) {
    // Deep-link / refresh with no wallet in `extra` → fall back to home
    // rather than force-unwrap-crash.
    if (state.extra is! T) {
      return missingWalletRedirect;
    }
    return null;
  },
  builder: (context, state) {
    final wallet = state.extra;
    if (wallet is! T) {
      return const SizedBox.shrink();
    }
    return BlocProvider(
      create: (_) => createCubit(walletId(wallet))..load(),
      child: CoinsScreen(
        onSend: (outpoints) => onSend(context, wallet, outpoints),
        onSweep: (outpoints) => onSweep(context, wallet, outpoints),
      ),
    );
  },
);
