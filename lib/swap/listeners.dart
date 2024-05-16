import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/bloc/home_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
          listenWhen: (previous, current) => previous.txPaid != current.txPaid,
          listener: (context, state) {
            final isReceivePage = context.read<NavName>().state == '/receive';
            final isSendPage = context.read<NavName>().state == '/send';

            if (isReceivePage || isSendPage) return;

            if (state.syncWallet != null || state.txPaid == null) return;

            final tx = state.txPaid!;
            final isSubmarine = tx.isSubmarine;

            final amt = !isSubmarine ? tx.recievableAmount()! : tx.outAmount;
            final amtStr =
                context.read<CurrencyCubit>().state.getAmountInUnits(amt);
            final prefix = tx.actionPrefixStr();

            showToastWidget(
              position: ToastPosition.top,
              AlertUI(text: '$prefix $amtStr'),
              animationCurve: Curves.decelerate,
            );

            context.read<WatchTxsBloc>().add(ClearAlerts());
          },
        ),
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) =>
              previous.syncWallet != current.syncWallet,
          listener: (context, state) async {
            if (state.syncWallet == null) return;
            if (state.txPaid == null) {
              context
                  .read<HomeCubit>()
                  .state
                  .getWalletBloc(state.syncWallet!)
                  ?.add(SyncWallet());
              context.read<WatchTxsBloc>().add(ClearAlerts());
              return;
            }

            final wallet = state.syncWallet!;
            final swap = state.txPaid!;
            final amt = swap.outAmount;
            final amtStr =
                context.read<CurrencyCubit>().state.getAmountInUnits(amt);
            final prefix = swap.actionPrefixStr();

            final tx = wallet.getTxWithSwap(swap)?.copyWith(wallet: wallet);
            if (tx == null) {
              showToastWidget(
                position: ToastPosition.top,
                AlertUI(text: '$prefix $amtStr'),
              );
              return;
            } else {
              try {
                final route = context.read<NavName>().state;
                final isReceivePage = route == '/receive';
                final isSwapReceivePage = route == '/swap-receive';
                final isSendPage = route == '/send';

                if (!isReceivePage && !isSwapReceivePage && !isSendPage)
                  showToastWidget(
                    position: ToastPosition.top,
                    AlertUI(
                      text: '$prefix $amtStr',
                      onTap: () {
                        locator<GoRouter>().push('/tx', extra: tx);
                      },
                    ),
                  );

                if (isReceivePage && !isSwapReceivePage)
                  locator<GoRouter>().push('/swap-receive', extra: tx);
              } catch (e) {
                // print('----> 3 $e');
              }
            }

            context.read<WatchTxsBloc>().add(ClearAlerts());

            await Future.delayed(const Duration(seconds: 5));

            context
                .read<HomeCubit>()
                .state
                .getWalletBloc(
                  wallet,
                )
                ?.add(SyncWallet());
          },
        ),
      ],
      child: child,
    );
  }
}
