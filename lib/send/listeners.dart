import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/currency/bloc/currency_state.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendListeners extends StatelessWidget {
  const SendListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CurrencyCubit, CurrencyState>(
          listener: (context, state) {
            context.read<SendCubit>().selectWallets();
            // context.read<SendCubit>().updateShowSend();
          },
        ),
        BlocListener<SendCubit, SendState>(
          listener: (context, state) {},
        ),
        BlocListener<SwapCubit, SwapState>(
          listener: (context, state) {
            // final amount = context.read<CurrencyCubit>().state.amount;
            // final inv = context.read<SendCubit>().state.invoice;
            // final address = context.read<SendCubit>().state.address;
            // if (inv != null &&
            //     inv.invoice == address &&
            //     inv.getAmount() != amount) {
            //   final amt = inv.getAmount();
            //   context.read<CurrencyCubit>().updateAmountDirect(amt);
            //   context.read<SendCubit>().updateShowSend();
            // }
          },
        ),
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
      ],
      child: child,
    );
  }
}
