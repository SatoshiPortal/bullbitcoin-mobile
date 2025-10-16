import 'package:bb_mobile/features/swap/presentation/swap_bloc.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_confirm_page.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_in_progress_page.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SwapRoute {
  swap('/swap'),
  confirmSwap('/swap/confirm'),
  inProgressSwap('/swap/in-progress');

  final String path;

  const SwapRoute(this.path);
}

class SwapRouter {
  static final route = GoRoute(
    name: SwapRoute.swap.name,
    path: SwapRoute.swap.path,
    builder:
        (context, state) => BlocProvider(
          create: (_) => locator<SwapCubit>()..init(),
          child: const SwapPage(),
        ),
    routes: [
      GoRoute(
        name: SwapRoute.confirmSwap.name,
        path: SwapRoute.confirmSwap.path,
        builder: (context, state) {
          final bloc = state.extra! as SwapCubit;

          return BlocProvider.value(
            value: bloc,
            child: const SwapConfirmPage(),
          );
        },
      ),
      GoRoute(
        name: SwapRoute.inProgressSwap.name,
        path: SwapRoute.inProgressSwap.path,
        builder: (context, state) {
          final bloc = state.extra! as SwapCubit;

          return BlocProvider.value(
            value: bloc,
            child: const SwapInProgressPage(),
          );
        },
      ),
    ],
  );
}
