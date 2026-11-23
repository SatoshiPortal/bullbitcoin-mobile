import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart' show ActiveEnvironmentReader;
import 'package:secrets/secrets.dart' show WalletInventory;
import 'package:swaps/swaps.dart';

import 'domain/get_swap_rescue_wallets_usecase.dart';
import 'presentation/swap_rescue_cubit.dart';
import 'presentation/swap_restore_cubit.dart';
import 'ui/swap_rescue_details_screen.dart';
import 'ui/swap_restore_screen.dart';

const swapRestoreRouteName = 'swapRestore';
const swapRescueRouteName = 'swapRescue';

/// Restoring swaps from the server and rescuing a funded one into an
/// admitted wallet of its destination chain.
List<GoRoute> swapRescueRoutes({
  required Swaps swaps,
  required WalletInventory inventory,
  required ActiveEnvironmentReader environment,
}) {
  final restore = RestoreSwapsUsecase(swaps.resolver, swaps.store);
  final rescue = RescueSwapUsecase(swaps.resolver, swaps.store, swaps.watcher);
  final wallets = GetSwapRescueWalletsUsecase(
    inventory: inventory,
    environment: environment,
  );
  return [
    GoRoute(
      name: swapRestoreRouteName,
      path: 'swap-restore',
      builder: (context, state) => BlocProvider(
        create: (_) => SwapRestoreCubit(restoreSwapsUsecase: restore)..restore(),
        child: const SwapRestoreScreen(),
      ),
    ),
    GoRoute(
      name: swapRescueRouteName,
      path: 'swap-rescue',
      redirect: (context, state) => state.extra is RestorableSwap
          ? null
          : state.namedLocation(swapRestoreRouteName),
      builder: (context, state) => switch (state.extra) {
        final RestorableSwap restorable => BlocProvider(
          create: (_) => SwapRescueCubit(
            rescueSwapUsecase: rescue,
            getRescueWalletsUsecase: wallets,
            restored: restorable.swap,
          ),
          child: SwapRescueDetailsScreen(restorable: restorable),
        ),
        _ => const SizedBox.shrink(),
      },
    ),
  ];
}
