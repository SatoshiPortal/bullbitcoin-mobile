import 'package:bb_mobile/_repository/apps_wallets_repository.dart';
import 'package:bb_mobile/_repository/network_repository.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';

class ReceiveListeners extends StatelessWidget {
  const ReceiveListeners({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ReceiveCubit, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.updateAddressGap != current.updateAddressGap,
          listener: (context, state) {
            if (state.updateAddressGap == null) return;

            context
                .read<NetworkCubit>()
                .updateStopGapAndSave(state.updateAddressGap!);
          },
        ),
        BlocListener<ReceiveCubit, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.switchToSecure != current.switchToSecure,
          listener: (context, state) {
            if (!state.switchToSecure) return;

            final network = context.read<NetworkRepository>().getBBNetwork;
            // final secureWallet =
            //     context.read<HomeCubit>().state.getMainSecureWallet(network);
            final secureWallet = context
                .read<AppWalletsRepository>()
                .getMainSecureWallet(network);
            if (secureWallet == null) return;
            context.read<ReceiveCubit>().updateWallet(secureWallet);
            context.read<ReceiveCubit>().clearSwitch();
          },
        ),
        BlocListener<ReceiveCubit, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.switchToInstant != current.switchToInstant,
          listener: (context, state) {
            if (!state.switchToInstant) return;

            final network = context.read<NetworkRepository>().getBBNetwork;
            final instantWallet = context
                .read<AppWalletsRepository>()
                .getMainInstantWallet(network);
            if (instantWallet == null) return;
            context.read<ReceiveCubit>().updateWallet(instantWallet);
            context.read<ReceiveCubit>().clearSwitch();
          },
        ),
        BlocListener<ReceiveCubit, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.defaultAddress != current.defaultAddress,
          listener: (context, state) {
            if (state.defaultAddress != null) return;

            context.read<CreateSwapCubit>().clearSwapTx();
            context.read<CurrencyCubit>().reset();
          },
        ),
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) =>
              previous.updatedSwapTx != current.updatedSwapTx &&
              current.updatedSwapTx != null,
          listener: (context, state) {
            final swapOnPage = context.read<CreateSwapCubit>().state.swapTx;
            if (swapOnPage == null) return;

            final isReceivePage = context.read<NavName>().state == '/receive';
            if (!isReceivePage) return;

            final swaptx = state.updatedSwapTx!;
            if (!swaptx.showAlert()) return;

            final sameSwap = swapOnPage.id == swaptx.id;
            if (sameSwap && swaptx.isChainSwap() == false) {
              locator<GoRouter>()
                ..pop()
                ..push('/swap-receive', extra: swaptx);
            } else if (sameSwap && swaptx.isChainSwap() == true) {
              final extra = [swaptx, true];
              locator<GoRouter>().pop();
              locator<GoRouter>().push('/onchain-swap-progress', extra: extra);
            } else {
              //TODO:DEBUG
              if (swaptx.isChainSwap()) return;
              final amtStr = context
                  .read<CurrencyCubit>()
                  .state
                  .getAmountInUnits(swaptx.outAmount);
              final prefix = swaptx.actionPrefixStr();
              showToastWidget(
                position: ToastPosition.top,
                AlertUI(text: '$prefix $amtStr'),
                animationCurve: Curves.decelerate,
              );
            }
          },
        ),
      ],
      child: child,
    );
  }
}
