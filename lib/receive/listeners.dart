import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_state.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
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
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) => previous.txPaid != current.txPaid,
          listener: (context, state) {
            if (state.syncWallet != null || state.txPaid == null) return;
            print('------ receive listener 1');
            final tx = state.txPaid!;
            print('------ receive listener 2');

            final amt = tx.recievableAmount()!;

            print('------ receive listener 3');

            final amtStr =
                context.read<CurrencyCubit>().state.getAmountInUnits(amt);
            print('------ receive listener 4');

            final prefix = tx.actionPrefixStr();
            print('------ receive listener 5');

            final isReceivePage = context.read<NavName>().state == '/receive';
            print('------ receive listener 6');

            final swapOnPage = context.read<SwapCubit>().state.swapTx;
            print('------ receive listener 7');

            final sameSwap = swapOnPage?.id == tx.id;
            print('------ receive listener 8');

            if (sameSwap && isReceivePage) {
              print('------ receive listener 9');

              locator<GoRouter>().push('/swap-receive', extra: tx);
            } else {
              print('------ receive listener 10');

              showToastWidget(
                position: ToastPosition.top,
                AlertUI(text: '$prefix $amtStr'),
                animationCurve: Curves.decelerate,
              );
            }
            print('------ receive listener 11');

            context.read<WatchTxsBloc>().add(ClearAlerts());
          },
        ),
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
// hello
// hello
