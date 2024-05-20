import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class SendInvAmtDisplay extends StatelessWidget {
  const SendInvAmtDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.select((SendCubit _) => _.state.invoice);
    if (inv == null) return const SizedBox.shrink();
    final isLiq = context
        .select((SendCubit _) => _.state.selectedWalletBloc?.state.isLiq());

    final amtStr = context.select(
      (CurrencyCubit _) => _.state.getAmountInUnits(
        inv.getAmount(),
        isLiquid: isLiq ?? false,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Amount to send'),
        const Gap(4),
        BBText.body(amtStr, isBold: true),
        const Gap(16),
        const _SwapFees(),
      ],
    );
  }
}

class _SwapFees extends StatelessWidget {
  const _SwapFees();

  @override
  Widget build(BuildContext context) {
    // final tx = context.select((SendCubit _) => _.state.tx);
    // final lockupFee = tx?.fee;
    // if (lockupFee == null) return const SizedBox.shrink();

    // final allFees = context.select((SwapCubit cubit) => cubit.state.allFees);
    // if (allFees == null) return const SizedBox.shrink();

    final swaptx = context.select((CreateSwapCubit _) => _.state.swapTx);
    if (swaptx == null) return const SizedBox.shrink();

    final isLiquid = swaptx.isLiquid();

    final lockupFee = swaptx.lockupFees;
    if (lockupFee == null) return const SizedBox.shrink();

    final fees = swaptx.totalFees();
    if (fees == null) return const SizedBox.shrink();

    final amt = context.select(
      (CurrencyCubit _) => _.state.getAmountInUnits(
        fees,
        isLiquid: isLiquid,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Total Fees'),
        const Gap(4),
        BBText.body(amt, isBold: true),
      ],
    );
  }
}

// class SendLnFees extends StatelessWidget {
//   const SendLnFees();

//   @override
//   Widget build(BuildContext context) {
//     final allFees =
//         context.select((CreateSwapCubit cubit) => cubit.state.allFees);
//     if (allFees == null) return const SizedBox.shrink();

//     final isLiq = context.select(
//       (SendCubit cubit) => cubit.state.selectedWalletBloc?.state.isLiq(),
//     );
//     if (isLiq == null) return const SizedBox.shrink();

//     final fees = isLiq ? allFees.lbtcSubmarine : allFees.btcSubmarine;
//     final totalFees =
//         fees.boltzFeesRate + fees.claimFees + fees.lockupFeesEstimate;

//     final amt = context.select(
//       (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
//         totalFees.toInt(),
//         isLiquid: isLiq,
//       ),
//     );

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         const BBText.title(
//           'Total Fees',
//         ),
//         const Gap(4),
//         BBText.body(
//           amt,
//           isBold: true,
//         ),
//       ],
//     );
//   }
// }

class SendingLnTx extends StatefulWidget {
  const SendingLnTx({super.key});

  @override
  State<SendingLnTx> createState() => _SendingLnTxState();
}

class _SendingLnTxState extends State<SendingLnTx> {
  late SwapTx swapTx;

  bool settled = false;
  bool paid = false;
  bool refund = false;

  @override
  void initState() {
    swapTx = context.read<CreateSwapCubit>().state.swapTx!;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final amount = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final isLiquid = swapTx.isLiquid();

    final amtStr = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        amount,
        isLiquid: isLiquid,
      ),
    );
    final tx = context.select((HomeCubit _) => _.state.getTxFromSwap(swapTx));

    return BlocListener<WatchTxsBloc, WatchTxsState>(
      listenWhen: (previous, current) =>
          previous.updatedSwapTx != current.updatedSwapTx &&
          current.updatedSwapTx != null,
      listener: (context, state) {
        // if (swapTx == null) return;
        final updatedSwap = state.updatedSwapTx!;
        if (updatedSwap.id != swapTx.id) return;
        setState(() {
          swapTx = updatedSwap;
        });

        if (updatedSwap.paidSubmarine()) {
          setState(() {
            paid = true;
          });
        }
        if (updatedSwap.settledSubmarine()) {
          setState(() {
            settled = true;
          });
        }

        if (updatedSwap.refundableSubmarine()) {
          setState(() {
            refund = true;
          });
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        // crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: double.infinity),
          if (!refund) ...[
            if (!settled) ...[
              if (!paid)
                const BBText.body('Payment in progess')
              else
                const BBText.body('Invoice paid'),
            ] else
              const BBText.body('Payment sent'),
          ] else
            const BBText.body(
              'Payment failed,\nRefund in progress.',
              textAlign: TextAlign.center,
            ),
          const Gap(16),
          if (!refund) SendTick(sent: settled),
          if (refund)
            const FaIcon(
              FontAwesomeIcons.triangleExclamation,
              color: Colors.red,
              size: 50,
            ),
          const Gap(16),
          BBText.body(amtStr),
          if (!settled) ...[
            const Gap(24),
            _OnChainWarning(swapTx: swapTx),
          ],
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

class SendTick extends StatelessWidget {
  const SendTick({super.key, required this.sent});

  final bool sent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      height: 300,
      width: double.infinity,
      duration: const Duration(milliseconds: 100),
      child: sent
          ? Center(
              child: LottieBuilder.asset(
                'assets/loaderanimation.json',
                repeat: false,
              ),
            )
          : const Center(
              child: SizedBox(
                height: 100,
                width: 100,
                child: CircularProgressIndicator(
                  color: Colors.lightGreen,
                  strokeWidth: 10,
                ),
              ),
            ),
    );
  }
}

class _OnChainWarning extends StatelessWidget {
  const _OnChainWarning({required this.swapTx});

  final SwapTx swapTx;

  @override
  Widget build(BuildContext context) {
    if (swapTx.isLiquid()) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          FontAwesomeIcons.triangleExclamation,
          color: context.colour.primary,
          size: 20,
        ),
        const Gap(8),
        const SizedBox(
          width: 250,
          child: BBText.bodySmall(
            'Your onchain payment has been sent, but the swap is still in progress. It will take on on-chain confirmation before the Lightning payment succeeds.',
            isRed: true,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
