import 'package:bb_mobile/features/consolidation/presentation/consolidation_cubit.dart';
import 'package:bb_mobile/features/consolidation/ui/screens/consolidation_screen.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ConsolidationRoute {
  consolidation('/consolidate/:walletId');

  const ConsolidationRoute(this.path);

  final String path;
}

class ConsolidationRouter {
  static final route = GoRoute(
    name: ConsolidationRoute.consolidation.name,
    path: ConsolidationRoute.consolidation.path,
    redirect: (context, state) {
      // Deep-link / refresh with no wallet id → fall back to home rather than
      // force-unwrap-crash.
      if (state.pathParameters['walletId'] == null) {
        return WalletRoute.walletHome.path;
      }
      return null;
    },
    builder: (context, state) {
      final walletId = state.pathParameters['walletId']!;
      return BlocProvider(
        create: (_) => locator<ConsolidationCubit>(param1: walletId)..load(),
        child: const ConsolidationScreen(),
      );
    },
  );
}
