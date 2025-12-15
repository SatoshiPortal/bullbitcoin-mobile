import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_filter_row.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_syncing_indicator.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: TopBar(
          title: 'Transactions',
          onBack: () {
            context.pop();
          },
        ),
        backgroundColor: context.appColors.onPrimary,
        elevation: 0,
      ),
      body: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final err = context.select((TransactionsCubit cubit) => cubit.state.err);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TxsFilterRow(),
        const TxsSyncingIndicator(),
        if (err != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: BBText(
              'Error - $err',
              style: context.font.bodyLarge,
              color: context.appColors.error,
            ),
          ),
        const Gap(16.0),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<WalletBloc>();
              bloc.add(const WalletRefreshed());
              await bloc.stream.firstWhere((state) => !state.isSyncing);
              if (!context.mounted) return;
              await context.read<TransactionsCubit>().loadTxs();
            },
            child: const TxList(),
          ),
        ),
      ],
    );
  }
}
