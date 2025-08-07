import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_state.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/pages/broadcast_signed_tx_page.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/pages/scan_nfc_page.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/pages/scan_qr_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum BroadcastSignedTxRoute {
  broadcastHome('/broadcast-signed-tx'),
  broadcastScanQr('scan-qr'),
  broadcastScanNfc('scan-nfc');

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
        routes: [
          GoRoute(
            name: BroadcastSignedTxRoute.broadcastScanQr.name,
            path: BroadcastSignedTxRoute.broadcastScanQr.path,
            builder:
                (context, state) => BlocListener<
                  BroadcastSignedTxCubit,
                  BroadcastSignedTxState
                >(
                  listenWhen:
                      (previous, state) =>
                          previous.transaction == null &&
                          state.transaction != null,
                  listener: (context, state) => context.pop(),
                  child: const ScanQrPage(),
                ),
          ),
          GoRoute(
            name: BroadcastSignedTxRoute.broadcastScanNfc.name,
            path: BroadcastSignedTxRoute.broadcastScanNfc.path,
            builder:
                (context, state) => BlocListener<
                  BroadcastSignedTxCubit,
                  BroadcastSignedTxState
                >(
                  listenWhen:
                      (previous, state) =>
                          previous.transaction == null &&
                          state.transaction != null,
                  listener: (context, state) => context.pop(),
                  child: const ScanNfcPage(),
                ),
          ),
        ],
      ),
    ],
  );
}
