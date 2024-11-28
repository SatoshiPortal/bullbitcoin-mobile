import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_pkg/boltz/swap.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/swap_history_bloc/swap_history_cubit.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SwapHistoryPage extends StatefulWidget {
  const SwapHistoryPage({super.key});

  @override
  State<SwapHistoryPage> createState() => _SwapHistoryPageState();
}

class _SwapHistoryPageState extends State<SwapHistoryPage> {
  late SwapHistoryCubit _swapHistory;

  @override
  void initState() {
    _swapHistory = SwapHistoryCubit(
      homeCubit: context.read<HomeCubit>(),
      networkCubit: context.read<NetworkCubit>(),
      boltz: locator<SwapBoltz>(),
      watcher: context.read<WatchTxsBloc>(),
    )..loadSwaps();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _swapHistory,
      child: const _SwapListener(child: _Screen()),
    );
  }
}

class _SwapListener extends StatelessWidget {
  const _SwapListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<WatchTxsBloc, WatchTxsState>(
      listenWhen: (previous, current) =>
          previous.updatedSwapTx != current.updatedSwapTx &&
          current.updatedSwapTx != null,
      listener: (context, state) =>
          context.read<SwapHistoryCubit>().swapUpdated(state.updatedSwapTx!),
      child: child,
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: BBAppBar(
          text: 'Swap History',
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap(24),
            _Panel(),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatefulWidget {
  const _Panel();

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  bool expanded1 = true;
  bool expanded2 = false;

  @override
  Widget build(BuildContext context) {
    // return Column(
    //   crossAxisAlignment: CrossAxisAlignment.stretch,
    //   children: [
    //     Padding(
    //       padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
    //       child: BBText.title(
    //         'Ongoing Swaps'.toUpperCase(),
    //         isBold: true,
    //       ),
    //     ),
    //     const Padding(
    //       padding: EdgeInsets.symmetric(horizontal: 8),
    //       child: SwapsList(),
    //     ),
    //   ],
    // );
    return ExpansionPanelList(
      dividerColor: context.colour.onPrimaryContainer,
      expandedHeaderPadding: EdgeInsets.zero,
      children: [
        ExpansionPanel(
          backgroundColor: context.colour.primaryContainer,
          isExpanded: expanded1,
          headerBuilder: (context, isExpanded) {
            return ListTile(
              dense: true,
              enabled: false,
              splashColor: Colors.transparent,
              iconColor: Colors.transparent,
              enableFeedback: false,
              visualDensity: VisualDensity.compact,
              onTap: () {
                // setState(() {
                //   expanded1 = !expanded1;
                // });
              },
              title: BBText.title(
                'Ongoing Swaps'.toUpperCase(),
                isBold: true,
              ),
            );
          },
          body: const SwapsList(),
        ),
        ExpansionPanel(
          backgroundColor: context.colour.primaryContainer,
          isExpanded: expanded2,
          canTapOnHeader: true,
          headerBuilder: (context, isExpanded) {
            return ListTile(
              dense: true,
              onTap: () {
                setState(() {
                  expanded2 = !expanded2;
                });
              },
              title: BBText.title(
                'Completed Swaps'.toUpperCase(),
                isBold: true,
              ),
            );
          },
          body: const TxList(),
        ),
      ],
    );
  }
}

class SwapsList extends StatelessWidget {
  const SwapsList({super.key});

  @override
  Widget build(BuildContext context) {
    final swaps = context.select((SwapHistoryCubit cubit) => cubit.state.swaps);
    return Column(
      children: swaps
          .map((swap) => SwapItem(swapTx: swap.$1, walletId: swap.$2))
          .toList(),
    );
  }
}

class TxList extends StatelessWidget {
  const TxList({super.key});

  @override
  Widget build(BuildContext context) {
    final txs = context.select(
      (SwapHistoryCubit cubit) => cubit.state.completeSwaps,
    );
    return Column(
      children: [
        if (txs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: BBText.bodySmall('No completed swaps'),
          )
        else
          ...txs.map((tx) => SwapItem(swapTx: tx.swapTx!)),
      ],
    );
  }
}

class SwapItem extends StatelessWidget {
  const SwapItem({super.key, required this.swapTx, this.walletId});

  final SwapTx swapTx;
  final String? walletId;

  @override
  Widget build(BuildContext context) {
    final status = swapTx.isChainSwap()
        ? swapTx.status?.status
            .getOnChainStr(swapTx.chainSwapDetails!.onChainType)
        : swapTx.status?.status.getStr(swapTx.isSubmarine());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
      child: Column(
        children: [
          // const Divider(),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText.bodySmall(
                    'Id: ' + swapTx.id,
                    isBold: true,
                  ),
                  if (swapTx.creationTime != null &&
                      swapTx.completionTime != null)
                    BBText.bodySmall(
                      'Duration: ' + (swapTx.getDuration() ?? 'N/A'),
                      isBold: true,
                    ),
                  BBText.bodySmall(
                    'Status: ' + (status?.$1 ?? ''),
                    isBold: true,
                  ),

                  // Expanded(
                  SizedBox(
                    width: 200,
                    child: BBText.bodySmall(
                      status?.$2 ?? '',
                      fontSize: 11,
                      // ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // copy id button
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color: context.colour.onPrimaryContainer,
                ),
                onPressed: () {
                  locator<Clippboard>().copy(swapTx.id);
                },
              ),
              if (walletId != null)
                RefreshButton(
                  swapTx: swapTx,
                  walletId: walletId!,
                ),
            ],
          ),
          // const Divider(),
        ],
      ),
    );
  }
}

class RefreshButton extends StatelessWidget {
  const RefreshButton({
    super.key,
    required this.swapTx,
    required this.walletId,
  });

  final SwapTx swapTx;
  final String walletId;

  @override
  Widget build(BuildContext context) {
    final loading = context.select(
      (SwapHistoryCubit cubit) => cubit.state.refreshing.contains(swapTx.id),
    );

    return SizedBox(
      width: 40,
      height: 40,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: loading
            ? const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(),
                ),
              )
            : IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: context.colour.onPrimaryContainer,
                ),
                onPressed: () {
                  context.read<SwapHistoryCubit>().refreshSwap(
                        swaptx: swapTx,
                        walletId: walletId,
                      );
                },
              ),
      ),
    );
  }
}
