import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/hidden_amount_icon.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/snap_scroll_list.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class ExchangeTransactionPreview extends StatelessWidget {
  const ExchangeTransactionPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransactionsCubit>(
      create: (context) =>
          locator<TransactionsCubit>(param1: null, param2: true)..loadTxs(),
      child: const _TransactionPreviewContent(),
    );
  }
}

class _TransactionPreviewContent extends StatelessWidget {
  const _TransactionPreviewContent();

  @override
  Widget build(BuildContext context) {
    final transactions = context.select(
      (TransactionsCubit cubit) => cubit.state.transactions,
    );

    final isLoading = transactions == null;
    final ordersList = transactions?.where((tx) => tx.isOrder).toList() ?? [];
    final isEmpty = transactions != null && ordersList.isEmpty;
    final txList = ordersList;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BBText(
                'Orders',
                style: context.font.titleSmall,
                color: context.appColors.text,
              ),
              GestureDetector(
                onTap: () =>
                    context.pushNamed(TransactionsRoute.transactions.name),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BBText(
                      context.loc.transactionFilterAll,
                      style: context.font.labelSmall,
                      color: context.appColors.primary,
                    ),
                    const Gap(2),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: context.appColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: context.appColors.primary.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: isLoading
                ? const _LoadingPlaceholder()
                : isEmpty
                    ? const _EmptyPlaceholder()
                    : SnapScrollList<Transaction>(
                        items: txList,
                        itemHeight: 64,
                        onExpand: () =>
                            context.pushNamed(TransactionsRoute.transactions.name),
                        itemBuilder: (context, tx, index) =>
                            _ExchangeTxPreviewItem(transaction: tx),
                      ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            LoadingLineContent(width: 16, height: 16, padding: EdgeInsets.zero),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LoadingLineContent(
                    width: 80,
                    height: 14,
                    padding: EdgeInsets.zero,
                  ),
                  const Gap(4),
                  LoadingLineContent(
                    width: 50,
                    height: 10,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const Gap(4),
            LoadingLineContent(width: 60, height: 14, padding: EdgeInsets.zero),
            const Gap(4),
            Icon(
              Icons.chevron_right,
              color: context.appColors.textMuted.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Center(
        child: BBText(
          'No orders yet',
          style: context.font.bodySmall,
          color: context.appColors.textMuted,
        ),
      ),
    );
  }
}

class _ExchangeTxPreviewItem extends StatelessWidget {
  const _ExchangeTxPreviewItem({required this.transaction});

  final Transaction transaction;

  String _getLabel(BuildContext context) {
    if (transaction.order != null) {
      return transaction.order!.orderType.value;
    }
    return transaction.isIncoming
        ? context.loc.transactionFilterReceive
        : context.loc.transactionFilterSend;
  }

  void _navigateToDetails(BuildContext context) {
    if (transaction.order != null) {
      context.pushNamed(
        TransactionsRoute.orderTransactionDetails.name,
        pathParameters: {'orderId': transaction.order!.orderId},
      );
    } else if (transaction.walletTransaction != null) {
      context.pushNamed(
        TransactionsRoute.transactionDetails.name,
        pathParameters: {'txId': transaction.walletTransaction!.txId},
        queryParameters: {'walletId': transaction.walletTransaction!.walletId},
      );
    }
  }

  Widget _buildAmount(BuildContext context, bool isReceive) {
    final order = transaction.order;
    if (order != null) {
      final (amount, currency) = order.amountAndCurrencyToDisplay();
      final displayAmount = amount is int ? amount : (amount as double).toStringAsFixed(2);
      return Text(
        '${isReceive ? '+' : '-'}$displayAmount $currency',
        style: context.font.bodyMedium?.copyWith(
          color: isReceive
              ? context.appColors.secondary
              : context.appColors.textMuted,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isReceive ? '+' : '-',
          style: context.font.bodyMedium?.copyWith(
            color: isReceive
                ? context.appColors.secondary
                : context.appColors.textMuted,
          ),
        ),
        CurrencyText(
          transaction.amountSat,
          showFiat: false,
          style: context.font.bodyMedium,
          color: isReceive
              ? context.appColors.secondary
              : context.appColors.textMuted,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReceive = transaction.isIncoming;
    final date = transaction.timestamp != null
        ? timeago.format(transaction.timestamp!)
        : null;
    final hideAmounts = context.select(
      (SettingsCubit cubit) => cubit.state.hideAmounts ?? false,
    );
    final label = _getLabel(context);

    return InkWell(
      onTap: () => _navigateToDetails(context),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isReceive ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 16,
                color: isReceive
                    ? context.appColors.secondary
                    : context.appColors.textMuted,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BBText(
                      label,
                      style: context.font.bodyMedium,
                      color: context.appColors.text,
                    ),
                    if (date != null)
                      BBText(
                        date,
                        style: context.font.labelSmall?.copyWith(fontSize: 10),
                        color: context.appColors.textMuted,
                      ),
                  ],
                ),
              ),
              const Gap(4),
              if (hideAmounts)
                HiddenAmountIcon(
                  size: 18,
                  color: context.appColors.textMuted,
                )
              else
                _buildAmount(context, isReceive),
              const Gap(4),
              Icon(
                Icons.chevron_right,
                color: context.appColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
