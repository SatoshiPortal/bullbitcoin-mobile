import 'package:send/src/consolidation/presentation/consolidation_cubit.dart';
import 'package:send/src/consolidation/ui/screens/consolidation_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:send/src/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:spend/spend.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ConsolidationRoute {
  consolidation('/consolidate/:walletId');

  const ConsolidationRoute(this.path);

  final String path;
}

GoRoute consolidationRoute({
  required Spend spend,
  required String missingWalletRedirect,
  required int? Function(BuildContext, String) selectBalanceSat,
}) => GoRoute(
  name: ConsolidationRoute.consolidation.name,
  path: ConsolidationRoute.consolidation.path,
  redirect: (context, state) {
    // Deep-link / refresh with no wallet id → fall back to home rather than
    // force-unwrap-crash.
    if (state.pathParameters['walletId'] == null) {
      return missingWalletRedirect;
    }
    return null;
  },
  builder: (context, state) {
    final walletId = state.pathParameters['walletId'];
    if (walletId == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => ConsolidationCubit(
        walletId: walletId,
        consolidateLiquidWalletUsecase: ConsolidateLiquidWalletUsecase(spend),
        spend: spend,
      )..load(),
      child: ConsolidationScreen(selectBalanceSat: selectBalanceSat),
    );
  },
);
