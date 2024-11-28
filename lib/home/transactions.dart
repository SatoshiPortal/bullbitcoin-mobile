import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/home_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_event.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:bb_mobile/wallet/bloc/state.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:extra_alignments/extra_alignments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class HomeTransactions extends StatefulWidget {
  const HomeTransactions({super.key});

  @override
  State<HomeTransactions> createState() => _HomeTransactionsState();
}

class _Listener extends StatelessWidget {
  const _Listener({
    // super.key,
    required this.child,
    required this.onUpdated,
  });

  final Widget child;
  final Function onUpdated;

  @override
  Widget build(BuildContext context) {
    final walletBlocs = context.select(
      (HomeCubit e) => e.state.walletBlocs ?? [],
    );

    if (walletBlocs.isEmpty) return child;
    return MultiBlocListener(
      listeners: [
        for (final walletBloc in walletBlocs)
          BlocListener<WalletBloc, WalletState>(
            bloc: walletBloc,
            listenWhen: (previous, current) =>
                previous.wallet?.transactions != current.wallet?.transactions ||
                previous.wallet?.swaps != current.wallet?.swaps,
            listener: (context, state) {
              onUpdated();
            },
          ),
      ],
      child: child,
    );
  }
}

class _HomeTransactionsState extends State<HomeTransactions> {
  @override
  Widget build(BuildContext context) {
    final _ = context.select((HomeCubit x) => x.state.updated);

    // final walletBlocs = context.select((HomeCubit _) => _.state.walletBlocs);
    final network = context.select((NetworkCubit x) => x.state.getBBNetwork());
    final txs =
        context.select((HomeCubit cubit) => cubit.state.getAllTxs(network));

    return _Listener(
      onUpdated: () {
        setState(() {});
      },
      child: RefreshIndicator(
        onRefresh: () async {
          final network = context.read<NetworkCubit>().state;

          final wallets = context
              .read<HomeCubit>()
              .state
              .walletBlocsFromNetwork(network.getBBNetwork());
          for (final wallet in wallets) {
            wallet.add(SyncWallet());
          }

          context.read<WatchTxsBloc>().add(WatchWallets());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (txs.isEmpty)
              const NoTxs()
            else ...[
              const HomeLoadingTxsIndicator(),
              Padding(
                padding:
                    const EdgeInsets.only(left: 32.0, bottom: 8, right: 32),
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
                  itemCount: txs.length,
                  cacheExtent: 50,
                  itemBuilder: (context, index) {
                    return HomeTxItem2(tx: txs[index]);
                  },
                ),
              ),
            ],
          ],
        ).animate(delay: 500.ms).fadeIn(),
      ),
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
            const BBText.titleLarge('No Transactions yet')
                .animate(delay: 300.ms)
                .fadeIn(),
            BBButton.text(
              label: 'Sync transactions',
              fontSize: 11,
              onPressed: () {
                final network =
                    context.read<NetworkCubit>().state.getBBNetwork();
                final wallets = context
                    .read<HomeCubit>()
                    .state
                    .walletBlocsFromNetwork(network);
                for (final wallet in wallets) {
                  wallet.add(SyncWallet());
                }
              },
            ),
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
    context.select((HomeCubit e) => e.state.walletBlocs);
    final network = context.select((NetworkCubit e) => e.state.getBBNetwork());
    final txs = context.select((HomeCubit e) => e.state.getAllTxs(network));

    if (txs.isEmpty) {
      return TopLeft(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 48.0,
          ),
          child: Column(
            children: [
              const BBText.titleLarge('No Transactions yet')
                  .animate(delay: 300.ms)
                  .fadeIn(),
              BBButton.text(
                label: 'Sync transactions',
                fontSize: 11,
                onPressed: () {
                  final network =
                      context.read<NetworkCubit>().state.getBBNetwork();
                  final wallets = context
                      .read<HomeCubit>()
                      .state
                      .walletBlocsFromNetwork(network);
                  for (final wallet in wallets) {
                    wallet.add(SyncWallet());
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: txs.length,
      itemBuilder: (context, index) {
        return HomeTxItem2(tx: txs[index]);
      },
    );
  }
}

// From Home page
class HomeTxItem2 extends StatelessWidget {
  const HomeTxItem2({super.key, required this.tx});

  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    // final showOnlySwap = tx.pageLayout == TxLayout.onlySwapTx;
    // if (showOnlySwap) return _SwapTxHomeListItem(transaction: tx);

    final label = tx.label ?? '';

    final amount = context.select(
      (CurrencyCubit x) => x.state
          .getAmountInUnits(tx.getAmount(sentAsTotal: true), removeText: true),
    );

    final units = context.select(
      (CurrencyCubit x) => x.state.getUnitString(isLiquid: tx.isLiquid),
    );

    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    // final img =
    //     darkMode ? 'assets/arrow_down_white.png' : 'assets/arrow_down.png';
    final isChainSwap = tx.isSwap && tx.swapTx!.isChainSwap();
    final isChainSelf = isChainSwap && tx.swapTx!.isChainSelf();
    final isChainReceive = isChainSwap && tx.swapTx!.isChainReceive();
    final imgBaseName =
        isChainSelf ? 'assets/images/swap_icon' : 'assets/images/arrow_down';
    final img = darkMode ? '${imgBaseName}_white.png' : '$imgBaseName.png';

    // final swapstatus =

    String statusImg = (tx.isSwap &&
            (tx.swapTx!.refundedAny() ||
                tx.swapTx!.refundableSubmarine() ||
                tx.swapTx!.refundableOnchain()))
        ? 'assets/tx_status_failed.png'
        : (tx.height == null || tx.height == 0)
            ? 'assets/tx_status_pending.png'
            : 'assets/tx_status_complete.png';
    if (isChainSwap == true) {
      // Special condition for chain receive, since tx.height will be null for ChainReceive.
      // Because this is a placeholder tx created to show the swap tx,
      // as the actual lockup tx happens in an external wallet.
      final swapStatus = tx.swapTx!.chainSwapAction();

      statusImg = swapStatus == ChainSwapActions.settled
          ? 'assets/tx_status_complete.png'
          : 'assets/tx_status_pending.png';

      statusImg = tx.swapTx!.refundedOnchain()
          ? 'assets/tx_status_failed.png'
          : statusImg;
    }

    final isReceive = tx.isReceived();

    final amt = '${isReceive ? '' : ''}${amount.replaceAll("-", "")}';

    // final wallet = tx.wallet!;

    return InkWell(
      onTap: () {
        context.push('/tx', extra: [tx, true]);
      },
      child: Padding(
        padding: const EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: 32,
          right: 32,
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(top: label.isEmpty ? 6 : 10.0),
              child: SizedBox(
                height: 24,
                width: 14,
                child: Container(
                  // color: Colors.red,
                  transformAlignment: Alignment.center,
                  transform: isChainSelf
                      ? (Matrix4.identity()..scale(2.0))
                      : Matrix4.identity()
                    ..rotateZ(isReceive || isChainReceive ? 0 : 3.16),
                  child: Image.asset(img),
                ),
              ),
            ),
            const Gap(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    BBText.titleLarge(amt),
                    const Gap(4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: BBText.bodySmall(units),
                    ),
                  ],
                ),
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
                ...[
                  WalletTag(tx: tx),
                  const Gap(2),
                ],
                if (tx.getBroadcastDateTime() != null)
                  Row(
                    children: [
                      BBText.bodySmall(
                        timeago.format(tx.getBroadcastDateTime()!),
                        removeColourOpacity: true,
                      ),
                      Image.asset(statusImg),
                    ],
                  )
                else
                  Row(
                    children: [
                      BBText.bodySmall(
                        (tx.timestamp == 0) ? 'Pending' : tx.getDateTimeStr(),
                        // : timeago.format(tx.getDateTime()),
                        removeColourOpacity: true,
                      ),
                      const Gap(2),
                      Image.asset(statusImg),
                    ],
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

// class _SwapTxHomeListItem extends StatelessWidget {
//   const _SwapTxHomeListItem({required this.transaction});

//   final Transaction transaction;

//   @override
//   Widget build(BuildContext context) {
//     final swap = transaction.swapTx;
//     if (swap == null) return const SizedBox.shrink();

//     final amt = swap.outAmount;
//     final amount = context.select(
//       (CurrencyCubit x) => x.state.getAmountInUnits(
//         amt,
//         isLiquid: transaction.isLiquid,
//       ),
//     );
//     final isReceive = !swap.isSubmarine;

//     // final invoice = swap.invoice;
//     final date = transaction.getDateTimeStr();

//     return InkWell(
//       onTap: () {
//         context.push('/tx', extra: transaction);
//       },
//       child: Padding(
//         padding: const EdgeInsets.only(
//           top: 8,
//           bottom: 16,
//           left: 24,
//           right: 24,
//         ),
//         child: Row(
//           children: [
//             Container(
//               transformAlignment: Alignment.center,
//               transform: Matrix4.identity()..rotateZ(isReceive ? 1.6 : -1.6),
//               child: const FaIcon(FontAwesomeIcons.arrowRight),
//             ),
//             const Gap(8),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 BBText.titleLarge(amount),
//                 // if (label.isNotEmpty) ...[
//                 //   const Gap(4),
//                 //   BBText.bodySmall(label),
//                 // ],
//               ],
//             ),
//             const Spacer(),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 BBText.bodySmall(
//                   date,
//                   // : timeago.format(tx.getDateTime()),
//                   removeColourOpacity: true,
//                 ),
//               ],
//             ),

//             // Align(
//             //   alignment: Alignment.bottomRight,
//             //   child: BBText.bodySmall(
//             //     label,
//             //   ),
//             // ),
//           ],
//         ),
//       ),
//     );
//   }
// }
