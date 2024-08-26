import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/send.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';

class SendingOnChainTx extends StatefulWidget {
  SendingOnChainTx({super.key, this.isReceive = false});

  bool isReceive;

  @override
  State<SendingOnChainTx> createState() => _SendingOnChainTxState();
}

class _SendingOnChainTxState extends State<SendingOnChainTx> {
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
    final defaultCurrency = context
        .select((CurrencyCubit cubit) => cubit.state.defaultFiatCurrency);
    final fiatAmt =
        context.select((CurrencyCubit cubit) => cubit.state.fiatAmt);
    final isTestNet =
        context.select((NetworkCubit cubit) => cubit.state.testnet);
    final unit = defaultCurrency?.name ?? '';
    final amt = isTestNet ? '0' : fiatAmt.toStringAsFixed(2);
    // final amt = fiatAmt.toStringAsFixed(2);

    return BlocListener<WatchTxsBloc, WatchTxsState>(
      listenWhen: (previous, current) =>
          current.updatedSwapTx?.id == swapTx?.id,
      // previous.updatedSwapTx != current.updatedSwapTx &&
      // current.updatedSwapTx != null,
      listener: (context, state) {
        // if (swapTx == null) return;
        final updatedSwap = state.updatedSwapTx!;
        // if (updatedSwap.id != swapTx?.id) return;
        String labelLocal = 'Broadcasting...';
        bool successLocal = false;
        bool failureLocal = false;
        if (updatedSwap.status?.status == SwapStatus.swapCreated) {
          labelLocal = 'Broadcasting...';
        } else if (updatedSwap.status?.status == SwapStatus.txnMempool) {
          // labelLocal = 'Our tx in mempool (1/3)';
          labelLocal = 'User Lockup Broadcasted (1/3)';
        } else if (updatedSwap.status?.status == SwapStatus.txnConfirmed) {
          labelLocal = 'User Lockup Confirmed!';
        } else if (updatedSwap.status?.status == SwapStatus.txnServerMempool) {
          labelLocal = 'Server Lockup Broadcasted (2/3)';
        } else if (updatedSwap.status?.status ==
            SwapStatus.txnServerConfirmed) {
          labelLocal = 'Claiming...(3/3)';
        } else if (updatedSwap.status?.status == SwapStatus.txnClaimed) {
          labelLocal = 'Success';
          successLocal = true;
        } else if (updatedSwap.status?.status == SwapStatus.txnLockupFailed) {
          labelLocal = 'Lockup failed. Initiating refund...';
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
          if (failure == false) SendTick(sent: success),
          const Gap(16),
          BBText.body(label),
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
          if (swapTx!.claimTxid == null) ...[
            // const Gap(24),
            _OnChainWarning(swapTx: swapTx!),
          ],
          // const Gap(40),
          // if (tx != null)
          //   BBButton.big(
          //     label: 'View Transaction',
          //     onPressed: () {
          //       context
          //         ..pop()
          //         ..pop()
          //         ..push('/tx', extra: [tx, false]);
          //     },
          //   ).animate().fadeIn(),
          // // if (paid && !settled) const BBText.body('Closing the swap ...'),
          if (success) const BBText.body('Swap complete'),
          const Gap(24),
        ],
      ),
    );
  }
}

class _OnChainWarning extends StatelessWidget {
  const _OnChainWarning({required this.swapTx});

  final SwapTx swapTx;

  @override
  Widget build(BuildContext context) {
    // if (swapTx.isLiquid()) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          FontAwesomeIcons.triangleExclamation,
          color: context.colour.primary,
          size: 20,
        ),
        const Gap(8),
        if (swapTx.isChainSelf()) ...[
          const BBText.bodySmall(
            'This will take a while.',
            isRed: true,
            fontSize: 12,
          ),
        ] else if (swapTx.isChainReceive()) ...[
          const SizedBox(
            width: 250,
            child: BBText.bodySmall(
              'Sender has made the onchain payment. It will take onchain confirmation until you can claim. This can take a while',
              isRed: true,
              fontSize: 12,
            ),
          ),
        ] else if (swapTx.isChainSend()) ...[
          const SizedBox(
            width: 250,
            child: BBText.bodySmall(
              'You have made the lockup transaction. It will take onchain confirmation until you can pay the receiver. This can take a while.',
              isRed: true,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
