import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/receive_page.dart';
import 'package:bb_mobile/swap/bloc/swap_bloc.dart';
import 'package:bb_mobile/transaction/bloc/transaction_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SwapHistoryButton extends StatelessWidget {
  const SwapHistoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final txs = context.select((WalletBloc _) => _.state.allSwapTxs());
    if (txs.isEmpty) return const SizedBox.shrink();

    return BBButton.bigNoIcon(
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
    final swapBloc = receiveCubit.state.swapBloc;
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
    final txs = context.select((WalletBloc _) => _.state.allSwapTxs());
    if (txs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BBHeader.popUpCenteredText(text: 'Lightning Invoices', isLeft: true),
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

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final swapTx = tx.swapTx;
    if (swapTx == null) return const SizedBox.shrink();

    final time = tx.getDateTimeStr();
    final invoice = swapTx.splitInvoice();
    final amount = swapTx.outAmount.toString() + ' sats';
    final idx = tx.swapIndex?.toString() ?? '00';
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
                BBText.bodySmall(time),
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

  static Future openPopUp(BuildContext context, Transaction tx) {
    return showBBBottomSheet(
      context: context,
      child: _InvoiceQRPopup(tx: tx),
    );
  }

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final swapTx = tx.swapTx;
    if (swapTx == null) return const SizedBox.shrink();

    final time = tx.getDateTimeStr();
    final amount = swapTx.outAmount.toString() + ' sats';
    final idx = tx.swapIndex?.toString() ?? '00';
    final status = swapTx.status?.toString() ?? '';

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
                  BBText.bodySmall(time),
                  BBText.bodySmall('invoice no. ' + idx),
                ],
              ),
            ],
          ),
          const Gap(24),
          Center(child: SizedBox(width: 250, child: ReceiveQRDisplay(address: swapTx.invoice))),
          const Gap(16),
          ReceiveDisplayAddress(addressQr: swapTx.invoice, fontSize: 9),
          const Gap(40),
        ],
      ),
    );
  }
}

class StatusActions extends StatelessWidget {
  const StatusActions({super.key});

  @override
  Widget build(BuildContext context) {
    final tx = context.select((TransactionCubit cubit) => cubit.state.tx);
    final swap = tx.swapTx;
    if (swap == null) return const SizedBox.shrink();

    final status = context.select((SwapBloc _) => _.state.showStatus(swap))?.toString() ?? '';

    return const Placeholder();
  }
}

class ClaimScreen extends StatelessWidget {
  const ClaimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
