import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';

class SwapAppListener extends StatelessWidget {
  const SwapAppListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) => previous.txPaid != current.txPaid,
          listener: (context, state) {
            if (state.txPaid == null) return;

            final isReceive = GoRouterState.of(context).uri.toString() == '/receive';

            final tx = state.txPaid!;

            if (isReceive) {
              context.go('/swap-receive', extra: tx);
            } else {
              showToastWidget(
                position: ToastPosition.bottom,
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(FontAwesomeIcons.circleCheck),
                      const Gap(8),
                      const BBText.body('Swap received'),
                      const Gap(24),
                      BBButton.text(
                        label: 'View',
                        onPressed: () {
                          context.go('/swap-receive', extra: tx);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            context.read<WatchTxsBloc>().add(ClearAlerts());
          },
        ),
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) => previous.syncWallet != current.syncWallet,
          listener: (context, state) {
            if (state.syncWallet == null) return;

            context
                .read<HomeCubit>()
                .state
                .getWalletBloc(
                  state.syncWallet!,
                )
                ?.add(SyncWallet());

            context.read<WatchTxsBloc>().add(ClearAlerts());
          },
        ),
      ],
      child: child,
    );
  }
}

class ReceiveSwapPaidSuccessPage extends StatelessWidget {
  const ReceiveSwapPaidSuccessPage({super.key, required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final amt = tx.getAmount();
    final amtStr = context.select((CurrencyCubit _) => _.state.getAmountInUnits(amt));
    return Scaffold(
      appBar: AppBar(flexibleSpace: const BBAppBar(text: 'Swap Received')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BBText.body('Payment received'),
          const Gap(16),
          const Icon(FontAwesomeIcons.circleCheck),
          const Gap(16),
          BBText.body(amtStr),
          const Gap(80),
          BBButton.big(
            label: 'View Transaction',
            onPressed: () {
              context.go('/tx', extra: tx);
            },
          ),
        ],
      ),
    );
  }
}

class ReceiveAlertPopUp extends StatelessWidget {
  const ReceiveAlertPopUp({super.key, required this.tx});

  static Future openPopUp(BuildContext context, Transaction tx) {
    return showDialog(
      context: context,
      builder: (context) {
        return ReceiveAlertPopUp(tx: tx);
      },
    );
  }

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
