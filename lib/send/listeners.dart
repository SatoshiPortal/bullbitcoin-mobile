import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/currency/bloc/currency_state.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/networkfees_cubit.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/bloc/send_state.dart';
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

            print('---- send listener 1');

            final tx = state.txPaid!;
            final amt = tx.outAmount;
            print('---- send listener 2');

            final amtStr =
                context.read<CurrencyCubit>().state.getAmountInUnits(amt);
            final prefix = tx.actionPrefixStr();
            print('---- send listener 3');

            final isSendPage = context.read<NavName>().state == '/send';

            print('---- send listener 4');

            final swapOnPage = context.read<SwapCubit>().state.swapTx;
            final sameSwap = swapOnPage?.id == tx.id;

            print('---- send listener 5 ' + (swapOnPage?.id ?? ''));
            print('---- send listener 5 ' + (tx.id));

            if (sameSwap && isSendPage) {
              context.read<SendCubit>().txSettled();
              print('---- send listener 6');
            } else {
              showToastWidget(
                position: ToastPosition.top,
                AlertUI(text: '$prefix $amtStr'),
                animationCurve: Curves.decelerate,
              );

              print('---- send listener 7');
            }

            print('---- send listener 8');
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
        BlocListener<SendCubit, SendState>(
          listenWhen: (previous, current) =>
              previous.selectedWalletBloc != current.selectedWalletBloc &&
              current.selectedWalletBloc != null,
          listener: (context, state) async {
            if (state.invoice == null) return;
            // await Future.delayed(2000.ms);
            final wallet = state.selectedWalletBloc!.state.wallet;
            // context.read<WalletBloc>().state.wallet;
            if (wallet == null) return;
            final isLiq = wallet.isLiquid();
            final networkurl = !isLiq
                ? context.read<NetworkCubit>().state.getNetworkUrl()
                : context.read<NetworkCubit>().state.getLiquidNetworkUrl();

            context.read<SwapCubit>().createSubSwapForSend(
                  wallet: wallet,
                  invoice: context.read<SendCubit>().state.address,
                  amount: context.read<CurrencyCubit>().state.amount,
                  isTestnet: context.read<NetworkCubit>().state.testnet,
                  networkUrl: networkurl,
                );

            // await Future.delayed(300.ms);

            // final fees =
            //     context.read<NetworkFeesCubit>().state.selectedOrFirst(true);

            // context.read<SendCubit>().buildTxFromSwap(
            //       networkFees: fees,
            //       swaptx: state.swapTx!,
            //     );
          },
        ),
        BlocListener<SwapCubit, SwapState>(
          listenWhen: (previous, current) => previous.swapTx != current.swapTx,
          listener: (context, state) async {
            if (state.swapTx == null) return;

            // await Future.delayed(300.ms);

            final fees =
                context.read<NetworkFeesCubit>().state.selectedOrFirst(true);

            context
                .read<SendCubit>()
                .buildTxFromSwap(networkFees: fees, swaptx: state.swapTx!);
          },
        ),
        BlocListener<SwapCubit, SwapState>(
          listenWhen: (previous, current) =>
              previous.updatedWallet != current.updatedWallet,
          listener: (context, state) async {
            print('--- send wallet listener 1');
            final updatedWallet = state.updatedWallet;
            print('--- send wallet listener 2');

            if (updatedWallet == null) return;

            print('--- send wallet listener 3');

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

            print('--- send wallet listener 4');
            final isTestnet = context.read<NetworkCubit>().state.testnet;

            print('--- send wallet listener 5');

            // await Future.delayed(100.ms);

            context
                .read<WatchTxsBloc>()
                .add(WatchWallets(isTestnet: isTestnet));

            print('--- send wallet listener 6');

            context.read<SwapCubit>().clearUpdatedWallet();
          },
        ),
      ],
      child: child,
    );
  }
}
