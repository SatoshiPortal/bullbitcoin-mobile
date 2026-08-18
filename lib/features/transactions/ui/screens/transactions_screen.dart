import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_filter_row.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_syncing_indicator.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart' show SliverToBoxAdapter;
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BullPage(
      padding: EdgeInsets.zero,
      topBar: BullTopBar(
        title: context.loc.transactionTitle,
        onBack: context.pop,
        actionIcon: BullIcons.contentCopy,
        onAction: () =>
            context.pushNamed(TransactionsRoute.exportTransactions.name),
      ),
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final err = context.select((TransactionsCubit cubit) => cubit.state.err);
    return BullPullableBody(
      onRefresh: () async {
        // Wait for the chain sync (bitcoin + liquid + swaps) to actually
        // finish before reloading the local tx list.
        await context.read<WalletBloc>().refresh();
        if (!context.mounted) return;
        await context.read<TransactionsCubit>().loadTxs();
      },
      slivers: [
        const SliverToBoxAdapter(child: TxsFilterRow()),
        const SliverToBoxAdapter(child: TxsSyncingIndicator()),
        if (err != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BullText(
                // `err` is a domain failure whose `toString()` is the Dart
                // default ("Instance of '…'"). Never interpolate it into a
                // user-facing string; the raw reason belongs in the logs.
                context.loc.oopsSomethingWentWrong,
                style: context.bullText.bodyLarge,
                color: context.bull.error,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: Gap(16.0)),
        const TxList(sliver: true),
      ],
    );
  }
}
