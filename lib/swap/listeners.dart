import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/bloc/home_state.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:oktoast/oktoast.dart';

class SwapAppListener extends StatelessWidget {
  const SwapAppListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext ctx) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HomeCubit, HomeState>(
          listenWhen: (previous, current) =>
              previous.loadingWallets != current.loadingWallets,
          listener: (context, state) {
            if (state.loadingWallets) return;

            final isTestnet = context.read<NetworkCubit>().state.testnet;
            context
                .read<WatchTxsBloc>()
                .add(WatchWallets(isTestnet: isTestnet));
          },
        ),
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) =>
              previous.updatedSwapTx != current.updatedSwapTx &&
              current.updatedSwapTx != null &&
              current.updatedSwapTx!.showAlert(),
          listener: (context, state) {
            final route = context.read<NavName>().state;
            final isReceivePage = route == '/receive';
            final isSendPage = route == '/send';
            final isSwapReceivePage = route == '/swap-receive';
            if (isReceivePage || isSendPage || isSwapReceivePage) return;

            final swapTx = state.updatedSwapTx!;
            final isSubmarine = swapTx.isSubmarine;

            final amt =
                !isSubmarine ? swapTx.recievableAmount()! : swapTx.outAmount;
            final amtStr =
                context.read<CurrencyCubit>().state.getAmountInUnits(amt);
            final prefix = swapTx.actionPrefixStr();

            showToastWidget(
              position: ToastPosition.top,
              AlertUI(text: '$prefix $amtStr'),
              animationCurve: Curves.decelerate,
            );
          },
        ),
      ],
      child: child,
    );
  }
}
