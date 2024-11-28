import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/receive_page.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
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
    final swapBloc = context.read<CreateSwapCubit>();
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
    final amount = '${swapTx.outAmount} sats';
    final idx = tx.lnSwapDetails!.keyIndex.toString();
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
                BBText.bodySmall('invoice no. $idx'),
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
    final swap = context.read<CreateSwapCubit>();
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

    final amount = '${swapTx.outAmount} sats';
    final idx = tx.lnSwapDetails!.keyIndex.toString();
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
                  BBText.bodySmall('invoice no. $idx'),
                ],
              ),
            ],
          ),
          const Gap(24),
          Center(
            child: SizedBox(
              width: 250,
              child: ReceiveQRDisplay(address: swapTx.lnSwapDetails!.invoice),
            ),
          ),
          const Gap(16),
          ReceiveDisplayAddress(
            addressQr: swapTx.lnSwapDetails!.invoice,
            fontSize: 9,
          ),
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

class _ReceivingSwapPageState extends State<ReceivingSwapPage>
    with WidgetsBindingObserver {
  late SwapTx swapTx;

  bool received = false;
  bool paid = false;
  bool inBackground = false;

  // Transaction? tx;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    swapTx = widget.tx;
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final inBg = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;

    if (inBackground && !inBg) {
      await Future.delayed(400.ms);

      if (!mounted) return;
      final updatedSwapTx = context.read<HomeCubit>().state.getSwapTxById(
            widget.tx.id,
          );

      if (updatedSwapTx == null) return;

      if (updatedSwapTx.paidReverse()) {
        setState(() {
          paid = true;
        });
      }
      if (updatedSwapTx.settledReverse()) {
        setState(() {
          received = true;
        });
      }
    }

    inBackground = inBg;
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    var amt = swapTx.recievableAmount() ?? 0;

    final tx = context.select(
      (HomeCubit cubit) => cubit.state.getTxFromSwap(swapTx),
    );

    if (tx != null) amt = tx.getAmount();

    final isSats = context.select((CurrencyCubit _) => _.state.unitsInSats);
    final amtDouble = isSats ? amt : amt / 100000000;

    final isLiq = swapTx.isLiquid();

    final amtStr = context.select(
      (CurrencyCubit _) => _.state.getAmountInUnits(
        amt,
        isLiquid: isLiq,
      ),
    );

    context.read<CurrencyCubit>().updateAmount(amtDouble.toString());
    final defaultCurrency = context
        .select((CurrencyCubit cubit) => cubit.state.defaultFiatCurrency);
    final fiatAmt =
        context.select((CurrencyCubit cubit) => cubit.state.fiatAmt);
    final isTestNet =
        context.select((NetworkCubit cubit) => cubit.state.testnet);
    final fiatUnit = defaultCurrency?.name ?? '';
    final fiatAmtStr = isTestNet ? '0' : fiatAmt.toStringAsFixed(2);

    return BlocListener<WatchTxsBloc, WatchTxsState>(
      listenWhen: (previous, current) =>
          previous.updatedSwapTx != current.updatedSwapTx &&
          current.updatedSwapTx != null,
      listener: (context, state) async {
        final updatedSwapTx = state.updatedSwapTx!;
        if (updatedSwapTx.id != swapTx.id) return;

        setState(() {
          swapTx = updatedSwapTx;
        });

        if (updatedSwapTx.paidReverse()) {
          setState(() {
            paid = true;
          });
        }
        if (updatedSwapTx.settledReverse()) {
          setState(() {
            received = true;
          });

          // await Future.delayed(100.ms);
          // tx = context.read<HomeCubit>().state.getTxFromSwap(widget.tx);
          // setState(() {});
        }
      },
      child: PopScope(
        onPopInvoked: (didPop) {
          // context.pop();
          // Future.microtask(() {
          //   context.pop();
          // });
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            flexibleSpace: BBAppBar(
              text: 'Payment Status',
              onBack: () {
                context.pop();
                // if (received)
                //   context.go('/home');
                // else
                //   context.pop();
              },
            ),
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLiq) ...[
                if (!received)
                  if (!paid) ...[
                    const BBText.body('Receiving payment'),
                  ] else ...[
                    const BBText.body('Invoice paid'),
                  ]
                else
                  const BBText.body('Payment received'),
                const Gap(16),
                ReceivedTick(received: received),
              ],
              if (!isLiq) ...[
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
              const Gap(16),
              BBText.body(amtStr),
              const Gap(4),
              const BBText.body('≈ '),
              const Gap(4),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BBText.body(fiatAmtStr),
                    const Gap(4),
                    BBText.body(fiatUnit),
                  ],
                ),
              ),
              if (!received && isLiq) ...[
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
                      ..push('/tx', extra: [tx, false]);
                  },
                ).animate().fadeIn(),
            ],
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
            'The sender has sent the lightning payment, but the swap is still in progress. It will take on on-chain confirmation before his Lightning payment succeeds.',
            isRed: true,
            fontSize: 12,
          ),
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
