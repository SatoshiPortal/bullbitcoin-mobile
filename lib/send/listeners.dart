import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/currency/bloc/currency_state.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_state.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';

class SendListeners extends StatelessWidget {
  const SendListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CurrencyCubit, CurrencyState>(
          listenWhen: (previous, current) => previous.amount != current.amount,
          listener: (context, state) {
            context.read<SendCubit>().checkBalance();
          },
        ),
        BlocListener<CreateSwapCubit, SwapState>(
          listenWhen: (previous, current) => previous.swapTx != current.swapTx,
          listener: (context, state) async {
            if (state.swapTx == null) return;

            final fees =
                context.read<NetworkFeesCubit>().state.selectedOrFirst(true);

            context
                .read<SendCubit>()
                .buildTxFromSwap(networkFees: fees, swaptx: state.swapTx!);
          },
        ),
        BlocListener<SendCubit, SendState>(
          listenWhen: (previous, current) =>
              previous.signed == false &&
              current.signed == true &&
              current.couldBeOnchainSwap() == true,
          listener: (context, state) async {
            final sendCubit = context.read<SendCubit>();
            final swapCubit = context.read<CreateSwapCubit>();
            context.pop();
            context.push('/swap-confirmation', extra: [sendCubit, swapCubit]);
          },
        ),
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) =>
              previous.updatedSwapTx != current.updatedSwapTx &&
              current.updatedSwapTx != null,
          listener: (context, state) {
            final swapOnPage = context.read<CreateSwapCubit>().state.swapTx;
            if (swapOnPage == null) return;

            final isSendPage = context.read<NavName>().state == '/send';
            if (!isSendPage) return;

            final swapTx = state.updatedSwapTx!;
            final sameSwap = swapOnPage.id == swapTx.id;
            if (sameSwap) return;

            if (!swapTx.showAlert()) return;

            //TODO:DEBUG
            if (swapTx.isChainSwap()) return;

            final amt = swapTx.outAmount;
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
