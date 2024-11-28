import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/fee_popup.dart';
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
    final inv = context.select((SendCubit e) => e.state.invoice);
    if (inv == null) return const SizedBox.shrink();
    final isLiq = context
        .select((SendCubit e) => e.state.selectedWalletBloc?.state.isLiq());

    final amtStr = context.select(
      (CurrencyCubit e) => e.state.getAmountInUnits(
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

    final swaptx = context.select((CreateSwapCubit e) => e.state.swapTx);
    if (swaptx == null) return const SizedBox.shrink();

    final isLiquid = swaptx.isLiquid();

    final lockupFee = swaptx.lockupFees;
    if (lockupFee == null) return const SizedBox.shrink();

    final fees = swaptx.totalFees();
    if (fees == null) return const SizedBox.shrink();

    final amt = context.select(
      (CurrencyCubit e) => e.state.getAmountInUnits(
        fees,
        isLiquid: isLiquid,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const BBText.title('Total Fees'),
            IconButton(
              icon: const Icon(Icons.info_outline),
              iconSize: 22.0,
              padding: EdgeInsets.zero,
              color: context.colour.onPrimaryContainer,
              onPressed: () {
                FeePopUp.openPopup(
                  context,
                  lockupFee,
                  swaptx.claimFees ?? 0,
                  swaptx.boltzFees ?? 0,
                );
                // show popup
              },
            ),
          ],
        ),
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
    final inv = context.select((SendCubit cubit) => cubit.state.invoice);
    final amount = inv?.getAmount() ?? 0;
    final isLiquid = swapTx.isLiquid();

    final amtStr = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        amount,
        isLiquid: isLiquid,
      ),
    );
    final tx = context.select((HomeCubit e) => e.state.getTxFromSwap(swapTx));

    final isSats = context.select((CurrencyCubit e) => e.state.unitsInSats);
    final amtDouble = isSats ? amount : amount / 100000000;

    context.read<CurrencyCubit>().updateAmount(amtDouble.toString());
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
              if (!paid && swapTx.isLiquid())
                const BBText.body('Payment in progress'),
              if (paid && swapTx.isLiquid()) const BBText.body('Invoice paid'),
            ] else
              const BBText.body('Payment sent'),
          ] else
            const BBText.body(
              'Payment failed,\nRefund in progress.',
              textAlign: TextAlign.center,
            ),
          const Gap(16),
          if (!refund)
            if (swapTx.isLiquid()) SendTick(sent: paid || settled),
          if (!swapTx.isLiquid()) ...[
            const Icon(
              FontAwesomeIcons.stopwatch,
              size: 80,
              color: Colors.lightGreen,
            ),
            const Gap(16),
            const BBText.body(
              'Swap created.\nThis will get settled in a while.',
              textAlign: TextAlign.center,
            ),
          ],
          if (refund)
            const FaIcon(
              FontAwesomeIcons.triangleExclamation,
              color: Colors.red,
              size: 50,
            ),
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
          if (paid && !settled) const BBText.body('Closing the swap ...'),
          if (settled) const BBText.body('Swap complete'),
          const Gap(24),
          // if (!settled) ...[
          //   const Gap(24),
          //   _OnChainWarning(swapTx: swapTx),
          // ],
          const Gap(24),
          if (tx != null)
            BBButton.big(
              label: 'View Transaction',
              onPressed: () {
                context
                  ..pop()
                  ..push('/tx', extra: [tx, false]);
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
