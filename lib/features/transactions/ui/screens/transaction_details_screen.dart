import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/transactions/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_details_table.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/transaction_label_bottomsheet.dart';
import 'package:bb_mobile/ui/components/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key, this.title});

  final String? title;

  Future<void> showTransactionLabelBottomSheet(BuildContext context) async {
    final receive = context.read<TransactionDetailsCubit>();

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colour.onPrimary,
      builder: (context) {
        return BlocProvider.value(
          value: receive,
          child: const TransactionLabelBottomsheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.transaction,
    );
    final amountSat = tx?.amountSat ?? 0;
    final isIncoming = tx?.direction == WalletTransactionDirection.incoming;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: title ?? 'Transaction details',
          actionIcon: Icons.close,
          onAction: () {
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                TransactionDirectionBadge(isIncoming: isIncoming),
                const Gap(24),
                BBText(
                  isIncoming ? 'Payment received' : 'Payment sent',
                  style: context.font.headlineLarge,
                ),
                const Gap(8),
                BBText(
                  FormatAmount.sats(amountSat),
                  style: context.font.displaySmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(24),
                const TransactionDetailsTable(),
                const Gap(62),
                if (tx != null)
                  BBButton.big(
                    label: 'Add note',
                    onPressed: () async {
                      await showTransactionLabelBottomSheet(context);
                    },
                    bgColor: Colors.transparent,
                    textColor: theme.colorScheme.secondary,
                    outlined: true,
                    borderColor: theme.colorScheme.secondary,
                  ),
                const Gap(16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
