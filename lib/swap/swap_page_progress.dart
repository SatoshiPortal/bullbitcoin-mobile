import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:boltz_dart/boltz_dart.dart' as boltz;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChainSwapProgressWidget extends StatefulWidget {
  const ChainSwapProgressWidget({super.key, this.isReceive = false});

  final bool isReceive;

  @override
  State<ChainSwapProgressWidget> createState() =>
      _ChainSwapProgressWidgetState();
}

class _ChainSwapProgressWidgetState extends State<ChainSwapProgressWidget> {
  late SwapTx? swapTx;
  late String label;
  bool success = false;
  bool failure = false;

  @override
  void initState() {
    swapTx = context.read<CreateSwapCubit>().state.swapTx;
    label = widget.isReceive == true ? 'Receiving...' : 'Broadcasting...';
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final amount = swapTx?.outAmount ?? 0;
    final isLiquid = swapTx?.isLiquid() ?? false;

    final amtStr = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        amount,
        isLiquid: isLiquid,
      ),
    );

    final isSats = context.select((CurrencyCubit _) => _.state.unitsInSats);
    final amtDouble = isSats ? amount : amount / 100000000;
    context.read<CurrencyCubit>().updateAmount(amtDouble.toString());
    context.select((CurrencyCubit cubit) => cubit.state.defaultFiatCurrency);
    context.select((CurrencyCubit cubit) => cubit.state.fiatAmt);
    context.select((NetworkCubit cubit) => cubit.state.testnet);
    Transaction? tx;
    if (swapTx?.isChainReceive() == false) {
      tx = context.select((SendCubit _) => _.state.tx);
    }

    return BlocListener<WatchTxsBloc, WatchTxsState>(
      listenWhen: (previous, current) =>
          current.updatedSwapTx?.id == swapTx?.id,
      listener: (context, state) {
        final updatedSwap = state.updatedSwapTx!;
        String labelLocal = 'Broadcasting...';
        const bool successLocal = false;
        bool failureLocal = false;
        if (updatedSwap.status?.status == boltz.SwapStatus.swapCreated) {
          labelLocal = 'Broadcasting...';
        } else if (updatedSwap.status?.status == boltz.SwapStatus.txnMempool ||
            updatedSwap.status?.status == boltz.SwapStatus.txnConfirmed ||
            updatedSwap.status?.status == boltz.SwapStatus.txnServerMempool) {
          labelLocal = 'Swap created.\nThis will get settled in a while.';
        } else if (updatedSwap.status?.status ==
            boltz.SwapStatus.txnLockupFailed) {
          labelLocal = 'Swap failed.\nInitiating refund';
          failureLocal = true;
        }

        setState(() {
          swapTx = updatedSwap;
          label = labelLocal;
          success = successLocal;
          failure = failureLocal;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: double.infinity),
          if (failure == false)
            const Icon(
              FontAwesomeIcons.stopwatch,
              size: 80,
              color: Colors.lightGreen,
            ),
          const Gap(24),
          BBText.body(
            label,
            textAlign: TextAlign.center,
          ),
          const Gap(16),
          BBText.body(amtStr),
          const Gap(4),
          // const BBText.body('≈'),
          // const Gap(4),
          // Center(
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       BBText.body(amt),
          //       const Gap(4),
          //       BBText.body(unit),
          //     ],
          //   ),
          // ),
          const Gap(24),
          if (tx != null)
            BBButton.big(
              label: 'View Transaction',
              onPressed: () {
                context.push('/tx', extra: [tx, true]);
              },
            ).animate().fadeIn(),
          // // if (paid && !settled) const BBText.body('Closing the swap ...'),
          if (success) const BBText.body('Swap complete'),
          const Gap(24),
        ],
      ),
    );
  }
}
