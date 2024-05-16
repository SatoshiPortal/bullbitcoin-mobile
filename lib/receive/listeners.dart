import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/swap/receive.dart';
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

            final network = context.read<NetworkCubit>().state.getBBNetwork();
            final secureWallet =
                context.read<HomeCubit>().state.getMainSecureWallet(network);
            if (secureWallet == null) return;
            context.read<ReceiveCubit>().updateWalletBloc(secureWallet);
            context.read<ReceiveCubit>().clearSwitch();
          },
        ),
        BlocListener<ReceiveCubit, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.switchToInstant != current.switchToInstant,
          listener: (context, state) {
            if (!state.switchToInstant) return;

            final network = context.read<NetworkCubit>().state.getBBNetwork();
            final instantWallet =
                context.read<HomeCubit>().state.getMainInstantWallet(network);
            if (instantWallet == null) return;
            context.read<ReceiveCubit>().updateWalletBloc(instantWallet);
            context.read<ReceiveCubit>().clearSwitch();
          },
        ),
        BlocListener<ReceiveCubit, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.defaultAddress != current.defaultAddress,
          listener: (context, state) {
            if (state.defaultAddress != null) return;

            context.read<SwapCubit>().clearSwapTx();
            context.read<CurrencyCubit>().reset();
          },
        ),
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) =>
              previous.updatedSwapTx != current.updatedSwapTx &&
              current.updatedSwapTx != null,
          listener: (context, state) {
            final swapOnPage = context.read<SwapCubit>().state.swapTx;
            if (swapOnPage == null) return;

            final isReceivePage = context.read<NavName>().state == '/receive';
            if (!isReceivePage) return;

            final swaptx = state.updatedSwapTx!;
            if (!swaptx.showAlert()) return;

            final sameSwap = swapOnPage.id == swaptx.id;
            if (sameSwap)
              locator<GoRouter>().push('/swap-receive', extra: swaptx);
            else {
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
