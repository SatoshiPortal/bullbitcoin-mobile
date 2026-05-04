import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_recovery_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_sales_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/screens/pos_home_screen.dart';
import 'package:bb_mobile/features/pos/presentation/screens/pos_pairing_screen.dart';
import 'package:bb_mobile/features/pos/presentation/screens/pos_recovery_screen.dart';
import 'package:bb_mobile/features/pos/presentation/screens/pos_sales_screen.dart';
import 'package:bb_mobile/features/pos/presentation/screens/pos_setup_screen.dart';
import 'package:bb_mobile/features/pos/presentation/screens/pos_terminals_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum PosRoute {
  home('/pos'),
  setup('/pos/setup'),
  pair('/pos/pair'),
  sales('/pos/sales'),
  terminals('/pos/terminals'),
  recovery('/pos/recovery');

  const PosRoute(this.path);

  final String path;
}

class PosRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create: (_) => locator<PosCubit>()..load(),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: PosRoute.home.name,
        path: PosRoute.home.path,
        redirect: _guard,
        builder: (context, state) => const PosHomeScreen(),
      ),
      GoRoute(
        name: PosRoute.setup.name,
        path: PosRoute.setup.path,
        redirect: _guard,
        builder: (context, state) => const PosSetupScreen(),
      ),
      GoRoute(
        name: PosRoute.pair.name,
        path: PosRoute.pair.path,
        redirect: _guard,
        builder: (context, state) => const PosPairingScreen(),
      ),
      GoRoute(
        name: PosRoute.sales.name,
        path: PosRoute.sales.path,
        redirect: _guard,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<PosSalesCubit>(),
          child: const PosSalesScreen(),
        ),
      ),
      GoRoute(
        name: PosRoute.terminals.name,
        path: PosRoute.terminals.path,
        redirect: _guard,
        builder: (context, state) => const PosTerminalsScreen(),
      ),
      GoRoute(
        name: PosRoute.recovery.name,
        path: PosRoute.recovery.path,
        redirect: _guard,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<PosRecoveryCubit>(),
          child: const PosRecoveryScreen(),
        ),
      ),
    ],
  );

  static String? _guard(BuildContext context, GoRouterState state) {
    final settings = context.read<SettingsCubit>().state;
    final allowed =
        (settings.isSuperuser ?? false) && (settings.isDevModeEnabled ?? false);
    return allowed ? null : WalletRoute.walletHome.path;
  }
}
