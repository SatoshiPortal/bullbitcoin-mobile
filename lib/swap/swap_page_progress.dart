import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/send.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SendingOnChainTx extends StatefulWidget {
  const SendingOnChainTx({super.key});

  @override
  State<SendingOnChainTx> createState() => _SendingOnChainTxState();
}

class _SendingOnChainTxState extends State<SendingOnChainTx> {
  late SwapTx swapTx;
  String label = 'Broadcasting...';
  bool success = false;

  @override
  void initState() {
    swapTx = context.read<CreateSwapCubit>().state.swapTx!;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final tx = context.select((HomeCubit _) => _.state.getTxFromSwap(swapTx));
    // final amount = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final amount = tx?.getAmount(sentAsTotal: true) ?? 0;
    final isLiquid = swapTx.isLiquid();

    final amtStr = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        amount,
        isLiquid: isLiquid,
      ),
    );

    context.read<CurrencyCubit>().updateAmount(amount.toString());
    final defaultCurrency = context
        .select((CurrencyCubit cubit) => cubit.state.defaultFiatCurrency);
    final fiatAmt =
        context.select((CurrencyCubit cubit) => cubit.state.fiatAmt);
    final isTestNet =
        context.select((NetworkCubit cubit) => cubit.state.testnet);
    final unit = defaultCurrency?.name ?? '';
    final amt = isTestNet ? '0' : fiatAmt.toStringAsFixed(2);

    return BlocListener<WatchTxsBloc, WatchTxsState>(
      listenWhen: (previous, current) =>
          previous.updatedSwapTx != current.updatedSwapTx &&
          current.updatedSwapTx != null,
      listener: (context, state) {
        // if (swapTx == null) return;
        final updatedSwap = state.updatedSwapTx!;
        if (updatedSwap.id != swapTx.id) return;

        String labelLocal = 'Broadcasting...';
        bool successLocal = false;
        if (updatedSwap.status?.status == SwapStatus.swapCreated) {
          labelLocal = 'Broadcasting...';
        } else if (updatedSwap.status?.status == SwapStatus.txnMempool) {
          labelLocal = 'Our txn waiting for confirmation (1/3)';
        } else if (updatedSwap.status?.status == SwapStatus.txnConfirmed) {
          labelLocal = 'Waiting for boltz payment';
        } else if (updatedSwap.status?.status == SwapStatus.txnServerMempool) {
          labelLocal = 'Boltz txn waiting for confirmation (2/3)';
        } else if (updatedSwap.status?.status ==
            SwapStatus.txnServerConfirmed) {
          labelLocal = 'Claiming... (3/3)';
        } else if (updatedSwap.status?.status == SwapStatus.txnClaimed) {
          labelLocal = 'Success / Swap complete';
          successLocal = true;
        }
        setState(() {
          swapTx = updatedSwap;
          label = labelLocal;
          success = successLocal;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: double.infinity),
          BBText.body(label),
          const Gap(16),
          SendTick(sent: success),
          // if (success) const SendTick(sent: true),
          //if (refund)
          //  const FaIcon(
          //    FontAwesomeIcons.triangleExclamation,
          //    color: Colors.red,
          //    size: 50,
          //  ),
          const Gap(16),
          BBText.body(amtStr),
          const Gap(4),
          const BBText.body('≈'),
          const Gap(4),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BBText.body(amt),
                const Gap(4),
                BBText.body(unit),
              ],
            ),
          ),
          const Gap(24),
          // if (paid && !settled) const BBText.body('Closing the swap ...'),
          if (success) const BBText.body('Swap complete'),
          const Gap(24),
          // if (!settled) ...[
          //   const Gap(24),
          //   // _OnChainWarning(swapTx: swapTx),
          // ],
          const Gap(40),
          if (tx != null)
            BBButton.big(
              label: 'View Transaction',
              onPressed: () {
                context
                  ..pop()
                  ..push('/tx', extra: tx);
              },
            ).animate().fadeIn(),
        ],
      ),
    );
  }
}

class _OnChainWarning {}
