import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/receive_page.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class SwapHistoryButton extends StatelessWidget {
  const SwapHistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final txs = context.select((WalletBloc _) => _.state.wallet?.swaps ?? []);
    if (txs.isEmpty) return const SizedBox.shrink();

    return BBButton.big(
      label: 'View History',
      onPressed: () {
        SwapTxList.openPopUp(context);
      },
    );
  }
}

class SwapTxList extends StatelessWidget {
  const SwapTxList({super.key});

  static Future openPopUp(BuildContext context) {
    final receiveCubit = context.read<ReceiveCubit>();
    final swapBloc = context.read<SwapCubit>();
    // receiveCubit.state.swapBloc;
    final walletBloc = receiveCubit.state.walletBloc;

    return showBBBottomSheet(
      context: context,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: receiveCubit),
          BlocProvider.value(value: swapBloc),
          if (walletBloc != null) BlocProvider.value(value: walletBloc),
        ],
        child: const SwapTxList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txs = context.select((WalletBloc _) => _.state.wallet?.swaps ?? []);
    if (txs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BBHeader.popUpCenteredText(
            text: 'Lightning Invoices',
            isLeft: true,
          ),
          const Gap(16),
          for (final tx in txs.reversed.toList()) SwapTxItem(tx: tx),
          // ListView.builder(
          //   physics: const NeverScrollableScrollPhysics(),
          //   shrinkWrap: true,
          //   primary: false,
          //   itemCount: txs.length,
          //   itemBuilder: (context, i) {
          //     final tx = txs[i];
          //     return SwapTxItem(tx: tx);
          //   },
          // ),
        ],
      ),
    );
  }
}

class SwapTxItem extends StatelessWidget {
  const SwapTxItem({super.key, required this.tx});

  final SwapTx tx;

  @override
  Widget build(BuildContext context) {
    final swapTx = tx;

    final invoice = swapTx.splitInvoice();
    final amount = swapTx.outAmount.toString() + ' sats';
    final idx = tx.keyIndex?.toString() ?? '0';
    final status = swapTx.status?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          _InvoiceQRPopup.openPopUp(context, tx);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText.body(amount, isBlue: true),
                  if (status.isNotEmpty) BBText.bodySmall(status),
                  BBText.bodySmall(invoice),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // BBText.bodySmall(time),
                BBText.bodySmall('invoice no. ' + idx),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceQRPopup extends StatelessWidget {
  const _InvoiceQRPopup({required this.tx});

  static Future openPopUp(BuildContext context, SwapTx tx) {
    final receive = context.read<ReceiveCubit>();
    final swap = context.read<SwapCubit>();
    return showBBBottomSheet(
      context: context,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: receive),
          BlocProvider.value(value: swap),
        ],
        child: _InvoiceQRPopup(tx: tx),
      ),
    );
  }

  final SwapTx tx;

  @override
  Widget build(BuildContext context) {
    final swapTx = tx;

    final amount = swapTx.outAmount.toString() + ' sats';
    final idx = tx.keyIndex?.toString() ?? '0';
    final status = swapTx.status?.toString() ?? '';
    final totalFees = swapTx.totalFees() ?? 0;
    final fees = context.select(
      (CurrencyCubit x) =>
          x.state.getAmountInUnits(totalFees, removeText: true),
    );
    final units = context.select(
      (CurrencyCubit cubit) => cubit.state.getUnitString(),
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BBHeader.popUpCenteredText(text: 'Invoice', isLeft: true),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BBText.body(amount, isBlue: true),
                    if (status.isNotEmpty) BBText.bodySmall(status),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // BBText.bodySmall(time),
                  BBText.bodySmall('invoice no. ' + idx),
                ],
              ),
            ],
          ),
          const Gap(24),
          Center(
            child: SizedBox(
              width: 250,
              child: ReceiveQRDisplay(address: swapTx.invoice),
            ),
          ),
          const Gap(16),
          ReceiveDisplayAddress(addressQr: swapTx.invoice, fontSize: 9),
          const Gap(24),
          if (totalFees != 0) ...[
            BBText.bodySmall('Total fees:\n$fees $units'),
            const Gap(16),
          ],
          const Gap(40),
        ],
      ),
    );
  }
}

// class StatusActions extends StatelessWidget {
//   const StatusActions({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final tx = context.select((TransactionCubit cubit) => cubit.state.tx);
//     final swap = tx.swapTx;
//     if (swap == null) return const SizedBox.shrink();

//     final status = context.select((WatchTxsBloc _) => _.state.showStatus(swap))?.toString() ?? '';

//     return const Placeholder();
//   }
// }

class ClaimScreen extends StatelessWidget {
  const ClaimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class AlertUI extends StatelessWidget {
  const AlertUI({required this.text, this.onTap});

  final String text;
  final Function? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      color: Colors.green,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FontAwesomeIcons.circleCheck),
          const Gap(8),
          BBText.body(text),
          const Spacer(),
          if (onTap != null)
            BBButton.text(
              label: 'View',
              onPressed: onTap!,
            ),
          const Gap(8),
        ],
      ),
    );
  }
}

class ReceivingSwapPage extends StatefulWidget {
  const ReceivingSwapPage({super.key, required this.tx});

  final SwapTx tx;

  @override
  State<ReceivingSwapPage> createState() => _ReceivingSwapPageState();
}

class _ReceivingSwapPageState extends State<ReceivingSwapPage> {
  bool received = false;
  Transaction? tx;

  @override
  Widget build(BuildContext context) {
    var amt = widget.tx.recievableAmount() ?? 0;

    // final tx = context.select(
    //   (HomeCubit cubit) => cubit.state.getTxFromSwap(widget.tx),
    // );

    if (tx != null) amt = tx!.getAmount();

    final amtStr =
        context.select((CurrencyCubit _) => _.state.getAmountInUnits(amt));

    return BlocListener<WatchTxsBloc, WatchTxsState>(
      listenWhen: (previous, current) => previous.txPaid != current.txPaid,
      listener: (context, state) async {
        final swapTx = state.txPaid;
        print('----> receiving 1');
        if (swapTx == null) return;
        print('----> receiving 2');
        if (swapTx.id != widget.tx.id) return;
        print('----> receiving 3');
        if (swapTx.settledReverse()) {
          print('----> receiving 4');

          setState(() {
            received = true;
          });
          print('----> receiving 5');

          await Future.delayed(100.ms);
          print('----> receiving 6');

          tx = context.read<HomeCubit>().state.getTxFromSwap(widget.tx);
          print('----> receiving 7');

          setState(() {});
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            text: 'Payment Status',
            onBack: () {
              if (received)
                context.go('/home');
              else
                context.pop();
            },
          ),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!received)
              const BBText.body('Receiving payment')
            else
              const BBText.body('Payment received'),
            const Gap(16),
            ReceivedTick(received: received),
            const Gap(16),
            BBText.body(amtStr),
            if (!received) ...[
              const Gap(24),
              _OnChainWarning(swapTx: widget.tx),
            ],
            const Gap(40),
            if (tx != null)
              BBButton.big(
                label: 'View Transaction',
                onPressed: () {
                  context.push('/tx', extra: tx);
                },
              ).animate().fadeIn(),
          ],
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
          size: 10,
        ),
        const Gap(4),
        const BBText.bodySmall(
          'On-chain payments can take a while to confirm',
          isRed: true,
          fontSize: 8,
        ),
      ],
    );
  }
}

class ReceivedTick extends StatelessWidget {
  const ReceivedTick({super.key, required this.received});

  final bool received;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      height: 300,
      width: double.infinity,
      duration: const Duration(milliseconds: 100),
      child: received
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
