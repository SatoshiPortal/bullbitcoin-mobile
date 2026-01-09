import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_confirm_page.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_in_progress_page.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_page.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_qr_scanner_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SwapRoute {
  swap('/swap'),
  confirmSwap('/swap/confirm'),
  inProgressSwap('/swap/in-progress'),
  scanQr('/swap/scan-qr');

  final String path;

  const SwapRoute(this.path);
}

class SwapRouter {
  static final route = GoRoute(
    name: SwapRoute.swap.name,
    path: SwapRoute.swap.path,
    builder:
        (context, state) => BlocProvider(
          create: (_) => locator<TransferBloc>()..add(const TransferStarted()),
          child: BlocListener<TransferBloc, TransferState>(
            listenWhen:
                (previous, current) =>
                    previous.signedPsbt.isEmpty &&
                    current.signedPsbt.isNotEmpty &&
                    ((current.swap != null && current.swap is ChainSwap) ||
                        current.isSameChainTransfer),
            listener: (context, state) {
              context.pushNamed(
                SwapRoute.confirmSwap.name,
                extra: context.read<TransferBloc>(),
              );
            },
            child: const SwapPage(),
          ),
        ),
    routes: [
      GoRoute(
        name: SwapRoute.confirmSwap.name,
        path: SwapRoute.confirmSwap.path,
        builder: (context, state) {
          final bloc = state.extra! as TransferBloc;

          return BlocProvider.value(
            value: bloc,
            child: BlocListener<TransferBloc, TransferState>(
              listenWhen:
                  (previous, current) =>
                      previous.txId.isEmpty && current.txId.isNotEmpty,
              listener: (context, state) {
                context.goNamed(
                  SwapRoute.inProgressSwap.name,
                  extra: context.read<TransferBloc>(),
                );
              },
              child: const SwapConfirmPage(),
            ),
          );
        },
      ),
      GoRoute(
        name: SwapRoute.inProgressSwap.name,
        path: SwapRoute.inProgressSwap.path,
        builder: (context, state) {
          final bloc = state.extra! as TransferBloc;

          return BlocProvider.value(
            value: bloc,
            child: const SwapInProgressPage(),
          );
        },
      ),
      GoRoute(
        name: SwapRoute.scanQr.name,
        path: SwapRoute.scanQr.path,
        builder: (context, state) => const SwapQrScannerPage(),
      ),
    ],
  );
}
