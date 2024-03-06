import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/home_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/transaction/bloc/state.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class HomeTransactions extends StatelessWidget {
  const HomeTransactions({super.key});

  @override
  Widget build(BuildContext context) {
    final __ = context.select((HomeCubit _) => _.state.walletBlocs);
    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    final txs = context.select((HomeCubit cubit) => cubit.state.allTxsWithSwaps(network));
    final last3Txs = txs.take(3).toList();

    if (txs.isEmpty) return const NoTxs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeLoadingTxsIndicator(),
        Padding(
          padding: const EdgeInsets.only(left: 24.0, bottom: 8, right: 24),
          child: Row(
            children: [
              const BBText.titleLarge(
                'Latest Transactions',
                isBold: true,
                fontSize: 16,
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  context.push('/transactions');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const BBText.bodySmall(
                      'view all',
                      isBlue: true,
                    ),
                    const Gap(4),
                    Icon(
                      FontAwesomeIcons.arrowRight,
                      size: 10,
                      color: context.colour.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: last3Txs.length,
            itemBuilder: (context, index) {
              return HomeTxItem2(tx: last3Txs[index]);
            },
          ),
        ),
      ],
    );
  }
}

class NoTxs extends StatelessWidget {
  const NoTxs({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TopLeft(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 48.0,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BBText.titleLarge('No Transactions yet').animate(delay: 300.ms).fadeIn(),
            const Gap(16),
            const HomeLoadingTxsIndicator(),
          ],
        ),
      ),
    );
  }
}

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: locator<HomeCubit>(),
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: const _TopAppBar(),
          automaticallyImplyLeading: false,
        ),
        body: const _TxList(),
      ),
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar();

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      text: 'Transaction History',
      onBack: () => context.pop(),
    );
  }
}

class _TxList extends StatelessWidget {
  const _TxList();

  @override
  Widget build(BuildContext context) {
    final __ = context.select((HomeCubit _) => _.state.walletBlocs);
    final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    final txs = context.select((HomeCubit _) => _.state.allTxsWithSwaps(network));

    if (txs.isEmpty)
      return TopLeft(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 48.0,
          ),
          child: const BBText.titleLarge('No Transactions yet').animate(delay: 300.ms).fadeIn(),
        ),
      );

    return ListView.builder(
      itemCount: txs.length,
      itemBuilder: (context, index) {
        return HomeTxItem2(tx: txs[index]);
      },
    );
  }
}

class HomeTxItem2 extends StatelessWidget {
  const HomeTxItem2({super.key, required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final showOnlySwap = tx.pageLayout == TxLayout.onlySwapTx;
    if (showOnlySwap) return _SwapTxHomeListItem(transaction: tx);

    final label = tx.label ?? '';

    final amount = context
        .select((CurrencyCubit x) => x.state.getAmountInUnits(tx.getAmount(sentAsTotal: true)));

    final isReceive = tx.isReceived();

    final amt = '${isReceive ? '' : ''}${amount.replaceAll("-", "")}';

    final wallet = tx.wallet;

    return InkWell(
      onTap: () {
        context.push('/tx', extra: tx);
      },
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 16,
          left: 24,
          right: 24,
        ),
        child: Row(
          children: [
            Container(
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()..rotateZ(isReceive ? 1.6 : -1.6),
              child: const FaIcon(FontAwesomeIcons.arrowRight),
            ),
            const Gap(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(amt),
                if (label.isNotEmpty) ...[
                  const Gap(4),
                  BBText.bodySmall(label),
                ],
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (wallet != null) ...[
                  WalletTag(wallet: wallet),
                  const Gap(4),
                ],
                if (tx.getBroadcastDateTime() != null)
                  BBText.bodySmall(
                    timeago.format(tx.getBroadcastDateTime()!),
                    removeColourOpacity: true,
                  )
                else
                  BBText.bodySmall(
                    (tx.timestamp == 0) ? 'Pending' : tx.getDateTimeStr(),
                    // : timeago.format(tx.getDateTime()),
                    removeColourOpacity: true,
                  ),
              ],
            ),

            // Align(
            //   alignment: Alignment.bottomRight,
            //   child: BBText.bodySmall(
            //     label,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class _SwapTxHomeListItem extends StatelessWidget {
  const _SwapTxHomeListItem({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final swap = transaction.swapTx;
    if (swap == null) return const SizedBox.shrink();

    final amt = swap.outAmount;
    final amount = context.select((CurrencyCubit x) => x.state.getAmountInUnits(amt));
    final isReceive = !swap.isSubmarine;

    // final invoice = swap.invoice;
    final date = transaction.getDateTimeStr();

    return InkWell(
      onTap: () {
        context.push('/tx', extra: transaction);
      },
      child: Padding(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 16,
          left: 24,
          right: 24,
        ),
        child: Row(
          children: [
            Container(
              transformAlignment: Alignment.center,
              transform: Matrix4.identity()..rotateZ(isReceive ? 1.6 : -1.6),
              child: const FaIcon(FontAwesomeIcons.arrowRight),
            ),
            const Gap(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.titleLarge(amount),
                // if (label.isNotEmpty) ...[
                //   const Gap(4),
                //   BBText.bodySmall(label),
                // ],
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BBText.bodySmall(
                  date,
                  // : timeago.format(tx.getDateTime()),
                  removeColourOpacity: true,
                ),
              ],
            ),

            // Align(
            //   alignment: Alignment.bottomRight,
            //   child: BBText.bodySmall(
            //     label,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
