import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_filter_row.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_syncing_indicator.dart';
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
        backgroundColor: context.colour.onPrimary,
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
              color: context.colour.error,
            ),
          ),
        const Gap(16.0),
        const Expanded(child: TxList()),
      ],
    );
  }
}
