import 'dart:async';

import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/swap/public/swap_route.dart'
    show SwapRouteArgs;
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_confirm_page.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_in_progress_page.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_page.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_qr_scanner_page.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
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
    builder: (context, state) => BlocProvider(
      create: (_) {
        final bloc = locator<TransferBloc>()..add(const TransferStarted());
        final extra = state.extra;
        if (extra is SwapRouteArgs) {
          unawaited(_prefillExternalDestination(bloc, extra));
        }
        return bloc;
      },
      child: BlocListener<TransferBloc, TransferState>(
        listenWhen: (previous, current) =>
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
              listenWhen: (previous, current) =>
                  previous.txId.isEmpty && current.txId.isNotEmpty,
              listener: (context, state) {
                final orderSwap = state.orderSwap;
                if (orderSwap != null) {
                  context.goNamed(
                    TransactionsRoute.orderSwapTransactionDetails.name,
                    pathParameters: {'localId': orderSwap.localId},
                    queryParameters: {'returnHome': 'true'},
                  );
                } else {
                  context.goNamed(
                    SwapRoute.inProgressSwap.name,
                    extra: context.read<TransferBloc>(),
                  );
                }
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

Future<void> _prefillExternalDestination(
  TransferBloc bloc,
  SwapRouteArgs args,
) async {
  bool isReady(TransferState state) =>
      !state.isStarting && state.wallets.isNotEmpty;
  try {
    final started = isReady(bloc.state)
        ? bloc.state
        : await bloc.stream.firstWhere(isReady);
    final from = started.wallets
        .where(
          (wallet) =>
              wallet.isLiquid != args.isLiquidAddress && wallet.signsLocally,
        )
        .firstOrNull;
    if (from == null) return;
    final others = started.wallets.where((wallet) => wallet.id != from.id);
    final to =
        others
            .where((wallet) => wallet.isLiquid == args.isLiquidAddress)
            .firstOrNull ??
        others.firstOrNull;
    if (to == null || bloc.isClosed) return;

    if (bloc.state.fromWallet?.id != from.id) {
      bloc.add(TransferEvent.walletsChanged(fromWallet: from, toWallet: to));
      await bloc.stream.firstWhere((state) => state.fromWallet?.id == from.id);
    }
    if (!bloc.state.sendToExternal) {
      bloc.add(const TransferEvent.sendToExternalToggled(true));
      await bloc.stream.firstWhere((state) => state.sendToExternal);
    }
    if (bloc.isClosed) return;
    bloc.add(TransferEvent.externalAddressChanged(args.externalAddress));
  } on StateError {
    return;
  }
}
