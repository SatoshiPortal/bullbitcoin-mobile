import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    final tx = context.select((SendCubit _) => _.state.tx);
    final lockupFee = tx?.fee;
    if (lockupFee == null) return const SizedBox.shrink();

    final allFees = context.select((SwapCubit cubit) => cubit.state.allFees);
    if (allFees == null) return const SizedBox.shrink();

    final isLiq = context.select(
      (SendCubit cubit) => cubit.state.selectedWalletBloc!.state.isLiq(),
    );

    final fees = isLiq ? allFees.lbtcSubmarine : allFees.btcSubmarine;

    final totalFees = fees.boltzFeesRate + fees.claimFees + lockupFee;

    final amt = context.select(
      (CurrencyCubit _) => _.state.getAmountInUnits(
        totalFees.toInt(),
        isLiquid: isLiq,
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

class SendLnFees extends StatelessWidget {
  const SendLnFees();

  @override
  Widget build(BuildContext context) {
    final allFees = context.select((SwapCubit cubit) => cubit.state.allFees);
    if (allFees == null) return const SizedBox.shrink();

    final isLiq = context.select(
      (SendCubit cubit) => cubit.state.selectedWalletBloc?.state.isLiq(),
    );
    if (isLiq == null) return const SizedBox.shrink();

    final fees = isLiq ? allFees.lbtcSubmarine : allFees.btcSubmarine;
    final totalFees =
        fees.boltzFeesRate + fees.claimFees + fees.lockupFeesEstimate;

    final amt = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        totalFees.toInt(),
        isLiquid: isLiq,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title(
          'Total Fees',
        ),
        const Gap(4),
        BBText.body(
          amt,
          isBold: true,
        ),
      ],
    );
  }
}

class SendingLnTx extends StatelessWidget {
  const SendingLnTx({super.key});

  @override
  Widget build(BuildContext context) {
    final settled = context.select((SendCubit cubit) => cubit.state.txSettled);

    final amount = context.select((CurrencyCubit cubit) => cubit.state.amount);
    final amtStr = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(amount));
    // final tx = context.select((SendCubit cubit) => cubit.state.tx);
    final tx = context.select((SendCubit cubit) => cubit.state.tx);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!settled)
          const BBText.body('Payment in progess')
        else
          const BBText.body('Payment sent'),
        const Gap(16),
        SendTick(sent: settled),
        const Gap(16),
        BBText.body(amtStr),
        const Gap(40),
        if (tx != null)
          BBButton.big(
            label: 'View Transaction',
            onPressed: () {
              final swap = context.read<SwapCubit>().state.swapTx;
              final txFromSwap =
                  context.read<HomeCubit>().state.getTxFromSwap(swap!);

              context
                ..pop()
                ..push('/tx', extra: txFromSwap ?? tx);
            },
          ).animate().fadeIn(),
      ],
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
