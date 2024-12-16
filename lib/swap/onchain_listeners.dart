import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
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

class OnchainListeners extends StatelessWidget {
  const OnchainListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SendCubit, SendState>(
          listenWhen: (previous, current) =>
              previous.sent == false && current.sent == true,
          listener: (context, state) async {
            final inConfPage =
                context.read<NavName>().state == '/swap-confirmation';
            if (inConfPage == false) return;
            final sendCubit = context.read<SendCubit>();
            final extra = [state.tx!.swapTx!, false, sendCubit];
            locator<GoRouter>().pop();
            locator<GoRouter>().push('/onchain-swap-progress', extra: extra);
          },
        ),
        BlocListener<CreateSwapCubit, SwapState>(
          listenWhen: (previous, current) => previous.swapTx != current.swapTx,
          listener: (context, state) async {
            if (state.swapTx == null) return;

            try {
              final fees =
                  context.read<NetworkFeesCubit>().state.selectedOrFirst(true);

              context.read<SendCubit>().buildOnchainTxFromSwap(
                    networkFees: fees,
                    swaptx: state.swapTx!,
                  );
            } catch (e) {
              debugPrint(e.toString());
            }
          },
        ),
        BlocListener<SendCubit, SendState>(
          listenWhen: (previous, current) =>
              previous.signed == false && current.signed == true,
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

            final amt = swapTx.outAmount;
            final amtStr =
                context.read<CurrencyCubit>().state.getAmountInUnits(amt);
            final prefix = swapTx.actionPrefixStr();

            //TODO:DEBUG
            if (swapTx.isChainSwap()) return;
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
