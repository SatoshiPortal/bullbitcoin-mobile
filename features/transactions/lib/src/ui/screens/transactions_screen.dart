import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:transactions/src/presentation/blocs/transactions_cubit.dart';
import 'package:transactions/src/presentation/transaction_failure_l10n.dart';

import '../transactions_navigation.dart';

import 'package:transactions/src/ui/widgets/tx_list.dart';
import 'package:transactions/src/ui/widgets/txs_filter_row.dart';
import 'package:transactions/src/ui/widgets/txs_syncing_indicator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullPullableBody, BullText, BullTopBar, Gap, BullTypographyX;
import 'package:go_router/go_router.dart';

class TransactionsScreen extends StatelessWidget {
  final Future<void> Function(BuildContext) refreshWallets;

  const TransactionsScreen({super.key, required this.refreshWallets});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: BullTopBar(
          title: context.loc.transactionTitle,
          onBack: () {
            context.pop();
          },
          actionIcon: Icons.file_download,
          actionTooltip: context.loc.exportTransactionsButton,
          onAction: () => TransactionsNavigation.openExport(context),
        ),
        backgroundColor: context.bull.onPrimary,
        elevation: 0,
      ),
      body: _Screen(refreshWallets: refreshWallets),
    );
  }
}

class _Screen extends StatelessWidget {
  final Future<void> Function(BuildContext) refreshWallets;

  const _Screen({required this.refreshWallets});

  @override
  Widget build(BuildContext context) {
    final failure = context.select(
      (TransactionsCubit cubit) => cubit.state.failure,
    );
    return BullPullableBody(
      onRefresh: () async {
        // Wait for the chain sync (bitcoin + liquid + swaps) to actually
        // finish before reloading the local tx list.
        await refreshWallets(context);
        // The global history reloads from the coordinator's completion signal.
      },
      slivers: [
        const SliverToBoxAdapter(child: TxsFilterRow()),
        const SliverToBoxAdapter(child: TxsSyncingIndicator()),
        if (failure != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BullText(
                failure.toTranslated(context),
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
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
