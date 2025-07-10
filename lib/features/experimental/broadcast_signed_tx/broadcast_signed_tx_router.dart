import 'package:bb_mobile/features/experimental/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/experimental/broadcast_signed_tx/presentation/broadcast_signed_tx_page.dart';
import 'package:bb_mobile/features/experimental/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/features/experimental/broadcast_signed_tx/presentation/scan_tx_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum BroadcastSignedTxRoute {
  broadcastHome('/broadcast-signed-tx/home'),
  broadcastScan('/broadcast-signed-tx/scan');

  const BroadcastSignedTxRoute(this.path);

  final String path;
}

class BroadcastSignedTxRouter {
  static final route = ShellRoute(
    builder:
        (context, state, child) => BlocProvider(
          create: (_) => locator<BroadcastSignedTxCubit>(),
          child: child,
        ),
    routes: [
      GoRoute(
        name: BroadcastSignedTxRoute.broadcastHome.name,
        path: BroadcastSignedTxRoute.broadcastHome.path,
        builder: (context, state) => const BroadcastSignedTxPage(),
      ),
      GoRoute(
        name: BroadcastSignedTxRoute.broadcastScan.name,
        path: BroadcastSignedTxRoute.broadcastScan.path,
        builder:
            (context, state) =>
                BlocListener<BroadcastSignedTxCubit, BroadcastSignedTxState>(
                  listenWhen:
                      (previous, state) =>
                          previous.transaction == null &&
                          state.transaction != null,
                  listener:
                      (context, state) => context.goNamed(
                        BroadcastSignedTxRoute.broadcastHome.name,
                      ),
                  child: const ScanTxPage(),
                ),
      ),
    ],
  );
}
