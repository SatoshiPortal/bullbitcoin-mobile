import 'package:bb_mobile/_model/transaction.dart';
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
      child: const _Screen(),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BBText.title(
                'Ongoing Swaps'.toUpperCase(),
                isBold: true,
              ),
              const Gap(8),
              const SwapsList(),
              const Gap(24),
              const BBText.title('Completed Swaps'),
              const TxList(),
            ],
          ),
        ),
      ),
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
      children: txs.map((tx) => SwapItem(swapTx: tx.swapTx!)).toList(),
    );
  }
}

class SwapItem extends StatelessWidget {
  const SwapItem({super.key, required this.swapTx, this.walletId});

  final SwapTx swapTx;
  final String? walletId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText.bodySmall('Swap id: ' + swapTx.id),
                BBText.bodySmall(
                  'Status: ' + (swapTx.status?.status.name ?? ''),
                ),
              ],
            ),
            const Spacer(),
            // copy id button
            IconButton(
              icon: Icon(
                Icons.copy,
                color: context.colour.onBackground,
              ),
              onPressed: () {
                context.read<Clippboard>().copy(swapTx.id);
              },
            ),
            if (walletId != null)
              RefreshButton(
                swapTx: swapTx,
                walletId: walletId!,
              ),
          ],
        ),
        const Divider(),
      ],
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

    return loading
        ? const CircularProgressIndicator()
        : IconButton(
            icon: Icon(
              Icons.refresh,
              color: context.colour.onBackground,
            ),
            onPressed: () {
              context.read<SwapHistoryCubit>().refreshSwap(
                    swaptx: swapTx,
                    walletId: walletId,
                  );
            },
          );
  }
}
