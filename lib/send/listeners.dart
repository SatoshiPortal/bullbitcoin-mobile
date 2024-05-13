import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/currency/bloc/currency_state.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:oktoast/oktoast.dart';

class SendListeners extends StatelessWidget {
  const SendListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) => previous.txPaid != current.txPaid,
          listener: (context, state) {
            if (state.syncWallet != null || state.txPaid == null) return;

            final tx = state.txPaid!;
            final amt = tx.outAmount;
            final amtStr =
                context.read<CurrencyCubit>().state.getAmountInUnits(amt);
            final prefix = tx.actionPrefixStr();

            final isSendPage = context.read<NavName>().state == '/send';

            final swapOnPage = context.read<SwapCubit>().state.swapTx;
            final sameSwap = swapOnPage?.id == tx.id;

            if (sameSwap && isSendPage)
              context.read<SendCubit>().txSettled();
            else
              showToastWidget(
                position: ToastPosition.top,
                AlertUI(text: '$prefix $amtStr'),
                animationCurve: Curves.decelerate,
              );

            context.read<WatchTxsBloc>().add(ClearAlerts());
          },
        ),
        BlocListener<CurrencyCubit, CurrencyState>(
          listener: (context, state) {
            context.read<SendCubit>().selectWallets();
            // context.read<SendCubit>().updateShowSend();
          },
        ),
        // BlocListener<SendCubit, SendState>(
        //   listener: (context, state) {},
        // ),
        // BlocListener<SwapCubit, SwapState>(
        //   listener: (context, state) {
        //     // final amount = context.read<CurrencyCubit>().state.amount;
        //     // final inv = context.read<SendCubit>().state.invoice;
        //     // final address = context.read<SendCubit>().state.address;
        //     // if (inv != null &&
        //     //     inv.invoice == address &&
        //     //     inv.getAmount() != amount) {
        //     //   final amt = inv.getAmount();
        //     //   context.read<CurrencyCubit>().updateAmountDirect(amt);
        //     //   context.read<SendCubit>().updateShowSend();
        //     // }
        //   },
        // ),
        BlocListener<SwapCubit, SwapState>(
          listenWhen: (previous, current) => previous.swapTx != current.swapTx,
          listener: (context, state) {
            if (state.swapTx == null) return;
            final fees =
                context.read<NetworkFeesCubit>().state.selectedOrFirst(true);

            context
                .read<SendCubit>()
                .confirmClickedd(networkFees: fees, swaptx: state.swapTx);
          },
        ),
        BlocListener<SwapCubit, SwapState>(
          listenWhen: (previous, current) =>
              previous.updatedWallet != current.updatedWallet,
          listener: (context, state) async {
            final updatedWallet = state.updatedWallet;
            if (updatedWallet == null) return;

            context
                .read<HomeCubit>()
                .state
                .getWalletBloc(
                  updatedWallet,
                )
                ?.add(
                  UpdateWallet(
                    updatedWallet,
                    updateTypes: [
                      UpdateWalletTypes.swaps,
                      UpdateWalletTypes.transactions,
                    ],
                  ),
                );

            final isTestnet = context.read<NetworkCubit>().state.testnet;

            context
                .read<WatchTxsBloc>()
                .add(WatchWallets(isTestnet: isTestnet));

            context.read<SwapCubit>().clearUpdatedWallet();
          },
        ),
      ],
      child: child,
    );
  }
}
